const Promise = require('bluebird')
const path = require('path')
const fs = Promise.promisifyAll(require('fs'))
const child = Promise.promisifyAll(require('child_process'))
const rimraf = require('rimraf')
const mkdirp = require('mkdirp')
const rimrafAsync = Promise.promisify(rimraf)
const mkdirpAsync = Promise.promisify(mkdirp)
const request = require('superagent')

const log = console.log

const TMPDIR = 'tmp/wisnuc'
const WISNUC = 'output/wisnuc'

/** create parent dirs **/
mkdirp.sync('tmp')
mkdirp.sync('output')

// constant
const addr = 'https://raw.githubusercontent.com'
// const updateUrl = `${addr}/wisnuc/appifi-bootstrap-update/release/appifi-bootstrap-update.packed.js`
const updateUrl = `${addr}/wisnuc/wisnuc-bootstrap-update/release/wisnuc-bootstrap-update`
// const bootstrapUrl = `${addr}/wisnuc/appifi-bootstrap/release/appifi-bootstrap.js.sha1`
const bootstrapUrl = `${addr}/wisnuc/wisnuc-bootstrap/release/wisnuc-bootstrap-linux-x64`
// node
const nodeUrl = 'https://nodejs.org/dist/v8.9.3/node-v8.9.3-linux-x64.tar.xz'
const nodeTar = nodeUrl.split('/').pop()
const nodeVer = nodeTar.split('-')[1].slice(1)

let release

// core function
// 1. if string, run it with child.spawn
// 2. if sync function, it is invoked to generate command line, aka, lazy
// 3. if async function, it is invoked with await
// 4. if array, then all entries are paralleled with promise.all
const spawnCommandAsync = async command => {
  if (typeof command === 'string') {
    return new Promise((resolve, reject) => {
      let cmds = command.trim().split(' ').filter(x => x.length > 0)
      let finished = false
      log(':: ', command)  
      let spawn = child.spawn(cmds[0], cmds.slice(1), { stdio: 'inherit' })
      spawn.on('error', err => (finished = true, reject(err)))
      spawn.on('exit', (code, signal) => {
        if (finished) return
        if (code || signal) {
          reject(new Error(`${cmds[0]} exit with code ${code} and signal ${signal}`))
        } else {
          resolve()
        }
      })
    })
  } else if (typeof command === 'function') {
    if (command.constructor.name === 'AsyncFunction') {
      return command()
    } else {
      return spawnCommandAsync(command())
    }
  } else if (Array.isArray(command)) {
    if (command.par) {
      return Promise.all(command.map(cmd => spawnCommandAsync(cmd)))
    } else {
      for (let i = 0; i < command.length; i++) {
        await spawnCommandAsync(command[i])
      }
    }
  }
}

// retrieve lastest non-beta release object
const retrieveAsync = async () => {
  let releases = await new Promise((resolve, reject) => request
    .get('https://api.github.com/repos/wisnuc/appifi-release/releases')
    .end((err, res) => err ? reject(err) : resolve(res.body)))

  release = releases.find(rel => rel.prerelease === false)
  if (!release) {
    log('no available release')
    process.exit(1)
  }
}

// repacked tarball file name
const repacked = () => `appifi-${release.tag_name}-${release.id}-${release.target_commitish.slice(0,8)}.tar.gz`

const cleanAll = [ 
  `rm -rf ${TMPDIR}`,
  `mkdir -p ${TMPDIR}`,
  `rm -rf ${WISNUC}`, 
  `mkdir ${WISNUC}`,
]

// does not reset ${WISNUC}, only ${WISNUC}/appifi-tarballs
// does not reset tmp dir, only ${TMPDIR}/appifi
const appifi = [
  `rm -rf ${WISNUC}/appifi-tarballs`,
  `mkdir -p ${WISNUC}/appifi-tarballs`,
  `rm -rf ${TMPDIR}/appifi`,
  `mkdir ${TMPDIR}/appifi`,

  // retrieve latest (nonpre-) release
  retrieveAsync,
  () => `wget -O ${TMPDIR}/appifi-${release.tag_name}-orig.tar.gz ${release.tarball_url}`,
  `mkdir -p ${TMPDIR}/appifi`,
  () => `tar xzf ${TMPDIR}/appifi-${release.tag_name}-orig.tar.gz -C ${TMPDIR}/appifi --strip-components=1`,  
  async () => fs.writeFileAsync(`${TMPDIR}/appifi/.release.json`, JSON.stringify(release, null, '  ')),
  () => `tar czf ${WISNUC}/appifi-tarballs/${repacked()} -C ${TMPDIR}/appifi .`
]

// use tmp dir
const node = [
  // download node and extract to target
  `wget -O ${TMPDIR}/${nodeTar} ${nodeUrl}`,
  `mkdir -p ${WISNUC}/node/${nodeVer}`,
  `tar xJf ${TMPDIR}/${nodeTar} -C ${WISNUC}/node/${nodeVer} --strip-components=1`,
  `ln -s ${nodeVer} ${WISNUC}/node/base`,
]

// does not use tmp dir
const wetty = [
  // download wetty
  `wget -O ${WISNUC}/wetty https://github.com/wisnuc/wetty/raw/master/wetty`,
  `chmod a+x ${WISNUC}/wetty`,
]

// does not use tmp dir
const bootstrapUpdate = [
  `wget -O ${WISNUC}/wisnuc-bootstrap-update ${updateUrl}`,
  `chmod a+x ${WISNUC}/wisnuc-bootstrap-update`,
]

// does not use tmp dir
const bootstrap = [
  `wget -O ${WISNUC}/wisnuc-bootstrap ${bootstrapUrl}`,
  `chmod a+x ${WISNUC}/wisnuc-bootstrap`,
] 

const tree = [
  `tree ${WISNUC} -L 3`
]

const jobs = process.argv.find(arg => arg === '-a' || arg === '--appifi-only') 
  ? [...appifi, ...tree]
  : [...cleanAll, ...appifi, ...node, ...wetty, ...bootstrapUpdate, ...bootstrap, ...tree]

spawnCommandAsync(jobs).then(x => x, e => console.log(e))


