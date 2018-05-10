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

const TMPDIR = 'tmp/root'
const ROOTDIR = 'output/phi'

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
// const nodeUrl = 'https://nodejs.org/dist/v8.9.3/node-v8.9.3-linux-x64.tar.xz'
const nodeUrl = 'https://nodejs.org/dist/v8.9.4/node-v8.9.4-linux-x64.tar.xz'
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
      let spawn = child.spawn(cmds[0], cmds.slice(1), { 
        env: process.env,
        stdio: 'inherit' 
      })
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

const fakeRetrieveAsync = async () => {
  release = {
    url: 'https://api.github.com/repos/wisnuc/appifi-release/releases/10097392',
    assets_url: 'https://api.github.com/repos/wisnuc/appifi-release/releases/10097392/assets',
    upload_url: 'https://uploads.github.com/repos/wisnuc/appifi-release/releases/10097392/assets{?name,label}',
    html_url: 'https://github.com/wisnuc/appifi-release/releases/tag/1.0.14',
    id: 10097392,
    tag_name: '9999.99.99',
    target_commitish: '0d5890cc84a7c321e5665ba0d263125fe3571387',
    name: 'fix smb bug',
    draft: false,
    author: {
      login: 'matianfu',
      id: 376881,
      avatar_url: 'https://avatars0.githubusercontent.com/u/376881?v=4',
      gravatar_id: '',
      url: 'https://api.github.com/users/matianfu',
      html_url: 'https://github.com/matianfu',
      followers_url: 'https://api.github.com/users/matianfu/followers',
      following_url: 'https://api.github.com/users/matianfu/following{/other_user}',
      gists_url: 'https://api.github.com/users/matianfu/gists{/gist_id}',
      starred_url: 'https://api.github.com/users/matianfu/starred{/owner}{/repo}',
      subscriptions_url: 'https://api.github.com/users/matianfu/subscriptions',
      organizations_url: 'https://api.github.com/users/matianfu/orgs',
      repos_url: 'https://api.github.com/users/matianfu/repos',
      events_url: 'https://api.github.com/users/matianfu/events{/privacy}',
      received_events_url: 'https://api.github.com/users/matianfu/received_events',
      type: 'User',
      site_admin: false
    },
    prerelease: false,
    created_at: '2018-03-15T06:55:02Z',
    published_at: '2018-03-15T06:56:24Z',
    assets: [],
    tarball_url: 'https://api.github.com/repos/wisnuc/appifi-release/tarball/1.0.14',
    zipball_url: 'https://api.github.com/repos/wisnuc/appifi-release/zipball/1.0.14',
    body: ''
  }
}

// repacked tarball file name
const repacked = () => `appifi-${release.tag_name}-${release.id}-${release.target_commitish.slice(0,8)}.tar.gz`

const cleanAll = [ 
  `rm -rf ${TMPDIR}`,
  `mkdir -p ${TMPDIR}`,
  `rm -rf ${ROOTDIR}`, 
  `mkdir ${ROOTDIR}`,
]

// does not reset ${ROOTDIR}, only ${ROOTDIR}/appifi-tarballs
// does not reset tmp dir, only ${TMPDIR}/appifi
/**
const appifi = [
  `rm -rf ${ROOTDIR}/appifi-tarballs`,
  `mkdir -p ${ROOTDIR}/appifi-tarballs`,
  `rm -rf ${TMPDIR}/appifi`,
  `mkdir ${TMPDIR}/appifi`,

  // retrieve latest (nonpre-) release
  retrieveAsync,
  () => `wget -O ${TMPDIR}/appifi-${release.tag_name}-orig.tar.gz ${release.tarball_url}`,
  `mkdir -p ${TMPDIR}/appifi`,
  () => `tar xzf ${TMPDIR}/appifi-${release.tag_name}-orig.tar.gz -C ${TMPDIR}/appifi --strip-components=1`,  
  async () => fs.writeFileAsync(`${TMPDIR}/appifi/.release.json`, JSON.stringify(release, null, '  ')),
  () => `tar czf ${ROOTDIR}/appifi-tarballs/${repacked()} -C ${TMPDIR}/appifi .`
]
**/

const appifi = [
  `rm -rf ${ROOTDIR}/appifi-tarballs`,
  `mkdir -p ${ROOTDIR}/appifi-tarballs`,
  `rm -rf ${TMPDIR}/appifi`,
  `mkdir ${TMPDIR}/appifi`,
  fakeRetrieveAsync,
  `./pull-station.sh ${TMPDIR}`,
  async () => fs.writeFileAsync(`${TMPDIR}/appifi/.release.json`, JSON.stringify(release, null, '  ')),
  () => `tar czf ${ROOTDIR}/appifi-tarballs/${repacked()} -C ${TMPDIR}/appifi .`,
]

// use tmp dir
const node = [
  // download node and extract to target
  `wget -O ${TMPDIR}/${nodeTar} ${nodeUrl}`,
  `mkdir -p ${ROOTDIR}/node/${nodeVer}`,
  `tar xJf ${TMPDIR}/${nodeTar} -C ${ROOTDIR}/node/${nodeVer} --strip-components=1`,
  `ln -s ${nodeVer} ${ROOTDIR}/node/base`,
]

// does not use tmp dir
const wetty = [
  // download wetty
  `wget -O ${ROOTDIR}/wetty https://github.com/wisnuc/wetty/raw/master/wetty`,
  `chmod a+x ${ROOTDIR}/wetty`,
]

// does not use tmp dir
const bootstrapUpdate = [
  `wget -O ${ROOTDIR}/wisnuc-bootstrap-update ${updateUrl}`,
  `chmod a+x ${ROOTDIR}/wisnuc-bootstrap-update`,
]

// does not use tmp dir
/**
const bootstrap = [
  `wget -O ${ROOTDIR}/wisnuc-bootstrap ${bootstrapUrl}`,
  `chmod a+x ${ROOTDIR}/wisnuc-bootstrap`,
] 
**/

const bootstrap = [
  `./pull-bootstrap.sh ${TMPDIR}`,
  `mv ${TMPDIR}/phi-bootstrap/app ${ROOTDIR}/phi-bootstrap`,
  `mv ${TMPDIR}/phi-bootstrap/.revision ${ROOTDIR}/.revision.bootstrap`,
  `chmod a+x ${ROOTDIR}/phi-bootstrap`,
]

const tree = [
  `tree ${ROOTDIR} -L 3`
]

const jobs = process.argv.find(arg => arg === '-a' || arg === '--appifi-only') 
  ? [...appifi, ...tree]
  : [...cleanAll, ...node, ...appifi, ...bootstrap, ...tree]

spawnCommandAsync(jobs).then(x => x, e => console.log(e))


