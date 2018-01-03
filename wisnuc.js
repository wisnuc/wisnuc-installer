const Promise = require('bluebird')
const path = require('path')
const fs = Promise.promisifyAll(require('fs'))
const child = Promise.promisifyAll(require('child_process'))
const request = require('superagent')

const log = console.log

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

const clean = [ 
  'rm -rf wisnuc', 
  'mkdir wisnuc' 
]

const appifi = [
  // latest appifi tarball
  'rm -rf wisnuc/appifi-tarballs',
  'mkdir wisnuc/appifi-tarballs',
  'rm -rf wisnuc-tmp',
  'mkdir -p wisnuc-tmp/appifi',
  retrieveAsync,
  () => `wget -O wisnuc-tmp/appifi-${release.tag_name}-orig.tar.gz ${release.tarball_url}`,
  () => `tar xzf wisnuc-tmp/appifi-${release.tag_name}-orig.tar.gz -C wisnuc-tmp/appifi --strip-components=1`,  
  async () => fs.writeFileAsync('wisnuc-tmp/appifi/.release.json', JSON.stringify(release, null, '  ')),
  () => `tar czf wisnuc/appifi-tarballs/${repacked()} -C wisnuc-tmp/appifi .`
]

const node = [
  // download node 8.9.3
  `wget -O wisnuc-tmp/${nodeTar} ${nodeUrl}`,
  `mkdir -p wisnuc/node/${nodeVer}`,
  `tar xJf wisnuc-tmp/${nodeTar} -C wisnuc/node/${nodeVer} --strip-components=1`,
  `ln -s ${nodeVer} wisnuc/node/base`,
]

const wetty = [
  // download wetty
  'wget -O wisnuc/wetty https://github.com/wisnuc/wetty/raw/master/wetty',
  'chmod a+x wisnuc/wetty',
]

const bootstrapUpdate = [
  // download wisnuc-bootstrap-update
  `wget -O wisnuc/wisnuc-bootstrap-update ${updateUrl}`,
  `chmod a+x wisnuc/wisnuc-bootstrap-update`,
]

const bootstrap = [
  // download wisnuc-bootstrap
  `wget -O wisnuc/wisnuc-bootstrap ${bootstrapUrl}`,
  `chmod a+x wisnuc/wisnuc-bootstrap`,
]

const jobs = process.argv.find(arg => arg === '--all') 
  ? [...clean, ...appifi, ...node, ...wetty, ...bootstrapUpdate, ...bootstrap]
  : appifi

spawnCommandAsync(jobs).then(x => x, e => console.log(e))


