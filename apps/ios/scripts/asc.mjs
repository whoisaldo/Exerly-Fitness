#!/usr/bin/env node
// Exerly-only provisioning and internal TestFlight. Never creates certificates,
// external groups, public links, review submissions, or a new team user.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { sign, X509Certificate } from 'node:crypto';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const origin = 'https://api.appstoreconnect.apple.com';
const bundle = 'com.exerly.fitness';
const groupName = 'Exerly Internal · Ali';
const keyID = '4Z7KFJ8DWZ';

export function createToken(key, id, issuer, now = Math.floor(Date.now() / 1000)) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const payload = `${encode({ alg: 'ES256', kid: id, typ: 'JWT' })}.${encode({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' })}`;
  return `${payload}.${sign('sha256', Buffer.from(payload), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}

export function apiURL(path) {
  const url = new URL(path, origin);
  if (url.origin !== origin || url.username || url.password) throw new Error('Refusing non-ASC URL');
  return url;
}

export function internalGroupBody(appID) {
  return { data: { type: 'betaGroups', attributes: { name: groupName,
    isInternalGroup: true, publicLinkEnabled: false, hasAccessToAllBuilds: false },
    relationships: { app: { data: { type: 'apps', id: appID } } } } };
}

export function validateGroup(group) {
  const a = group.attributes;
  if (a.isInternalGroup !== true || a.publicLinkEnabled || a.hasAccessToAllBuilds) {
    throw new Error('Group must be internal, have no public link and require explicit build assignment');
  }
}

export function validateTester(tester, email) {
  // inviteType is EMAIL or PUBLIC_LINK, not the internal/external distinction.
  // Call only for a member returned from the validated internal group.
  if (tester.attributes.email?.toLowerCase() !== email.toLowerCase() || tester.attributes.inviteType !== 'EMAIL') {
    throw new Error('Only the account holder with an email invitation is permitted');
  }
}

async function client() {
  const dir = join(homedir(), 'private_keys');
  const [key, issuer] = await Promise.all([readFile(join(dir, `AuthKey_${keyID}.p8`)), readFile(join(dir, 'asc-issuer-id.txt'), 'utf8')]);
  return async function request(path, method = 'GET', body) {
    const response = await fetch(apiURL(path), { method, signal: AbortSignal.timeout(30000),
      redirect: 'error', headers: { Authorization: `Bearer ${createToken(key, keyID, issuer.trim())}`, 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}) });
    if (response.status === 204) return {};
    const result = await response.json();
    if (!response.ok) throw new Error(`ASC ${response.status}: ${result.errors?.map(e => `${e.code}: ${e.detail}`).join('; ') ?? 'request failed'}`);
    return result;
  };
}

async function all(request, path) {
  const data = [];
  while (path) {
    const result = await request(path);
    data.push(...result.data);
    path = result.links?.next;
  }
  return data;
}

async function findApp(request) {
  const apps = await all(request, `/v1/apps?filter[bundleId]=${bundle}`);
  if (apps.length > 1) throw new Error('Ambiguous Exerly app');
  return apps[0];
}

async function provision(request) {
  const certificateDir = join(homedir(), 'private_keys/eternalmonitor-distribution');
  const certificateID = (await readFile(join(certificateDir, 'certificate-id.txt'), 'utf8')).trim();
  const cert = (await request(`/v1/certificates/${encodeURIComponent(certificateID)}`)).data;
  const localCert = new X509Certificate(await readFile(join(certificateDir, 'distribution.pem')));
  const remoteCert = new X509Certificate(Buffer.from(cert.attributes.certificateContent, 'base64'));
  if (cert.attributes.certificateType !== 'DISTRIBUTION' || localCert.fingerprint256 !== remoteCert.fingerprint256 ||
      Date.parse(cert.attributes.expirationDate) <= Date.now()) throw new Error('Authorized distribution certificate unavailable');
  let [identifier] = await all(request, `/v1/bundleIds?filter[identifier]=${bundle}`);
  if (!identifier) identifier = (await request('/v1/bundleIds', 'POST', { data: { type: 'bundleIds',
    attributes: { name: 'Exerly', identifier: bundle, platform: 'IOS' } } })).data;
  if (identifier.attributes.identifier !== bundle) throw new Error('Unexpected bundle identifier');
  const capabilities = await all(request, `/v1/bundleIds/${identifier.id}/bundleIdCapabilities`);
  let capabilityChanged = false;
  if (!capabilities.some(c => c.attributes.capabilityType === 'HEALTHKIT')) {
    await request('/v1/bundleIdCapabilities', 'POST', { data: { type: 'bundleIdCapabilities',
      attributes: { capabilityType: 'HEALTHKIT' }, relationships: { bundleId: { data: { type: 'bundleIds', id: identifier.id } } } } });
    capabilityChanged = true;
  }
  const profiles = await all(request, `/v1/bundleIds/${identifier.id}/profiles?limit=200`);
  let profile;
  for (const candidate of profiles.filter(p => p.attributes.profileType === 'IOS_APP_STORE' && p.attributes.profileState === 'ACTIVE'
    && Date.parse(p.attributes.expirationDate) > Date.now() + 86400000 && !capabilityChanged)) {
    const certificates = await all(request, `/v1/profiles/${candidate.id}/certificates`);
    if (certificates.some(c => c.id === certificateID)) { profile = candidate; break; }
  }
  if (!profile) profile = (await request('/v1/profiles', 'POST', { data: { type: 'profiles',
    attributes: { name: `Exerly App Store ${new Date().toISOString().replace(/[:.]/g, '-')}`, profileType: 'IOS_APP_STORE' },
    relationships: { bundleId: { data: { type: 'bundleIds', id: identifier.id } },
      certificates: { data: [{ type: 'certificates', id: certificateID }] } } } })).data;
  if (!profile.attributes.profileContent) profile = (await request(`/v1/profiles/${profile.id}`)).data;
  const output = join(homedir(), 'private_keys/exerly-distribution');
  await mkdir(output, { recursive: true, mode: 0o700 });
  await writeFile(join(output, `${bundle}.mobileprovision`), Buffer.from(profile.attributes.profileContent, 'base64'), { mode: 0o600 });
  console.log(JSON.stringify({ bundle, bundleID: identifier.id, profileID: profile.id,
    expires: profile.attributes.expirationDate, profileDirectory: output, healthKit: true }));
}

async function internal(request, app, buildNumber) {
  const users = await all(request, '/v1/users?limit=200');
  const owners = users.filter(u => u.attributes.firstName === 'Ali' && u.attributes.lastName === 'Younes' && u.attributes.roles.includes('ACCOUNT_HOLDER'));
  if (owners.length !== 1) throw new Error('Could not uniquely identify the authorized account holder');
  const email = owners[0].attributes.username;
  if (!email) throw new Error('Account holder email unavailable');
  const groups = await all(request, `/v1/apps/${app.id}/betaGroups?limit=200`);
  let group = groups.find(g => g.attributes.name === groupName);
  if (!group) group = (await request('/v1/betaGroups', 'POST', internalGroupBody(app.id))).data;
  validateGroup(group);
  const members = await all(request, `/v1/betaGroups/${group.id}/betaTesters?limit=200`);
  // The website's internal-tester picker identifies a team user. A global
  // email search can return several testers and does not establish that role.
  if (members.length !== 1) throw new Error('Add only Ali to this internal group in App Store Connect, then rerun');
  for (const member of members) validateTester(member, email);
  if (buildNumber) {
    const builds = await all(request, `/v1/builds?filter[app]=${app.id}&filter[version]=${encodeURIComponent(buildNumber)}`);
    if (builds.length !== 1 || builds[0].attributes.processingState !== 'VALID' || builds[0].attributes.expired) {
      throw new Error('Requested build is not a unique, valid, unexpired processed build');
    }
    await request(`/v1/betaGroups/${group.id}/relationships/builds`, 'POST', { data: [{ type: 'builds', id: builds[0].id }] });
  }
  console.log(JSON.stringify({ appID: app.id, groupID: group.id, internal: true, testers: 1, assignedBuild: buildNumber ?? null }));
}

async function main() {
  const [command = 'status', buildNumber] = process.argv.slice(2);
  if (!['status', 'provision', 'internal'].includes(command) || (buildNumber && !/^\d+$/.test(buildNumber))) {
    throw new Error('Usage: node asc.mjs [status|provision|internal [build-number]]');
  }
  const request = await client();
  if (command === 'provision') return provision(request);
  const app = await findApp(request);
  if (!app) {
    console.log(JSON.stringify({ bundle, appRecord: false, next: 'Create Exerly in App Store Connect: iOS, English (US), com.exerly.fitness, SKU sideband-exerly-ios. The REST API cannot create app records.' }));
    process.exitCode = 2;
    return;
  }
  if (command === 'internal') return internal(request, app, buildNumber);
  const builds = await all(request, `/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=10`);
  console.log(JSON.stringify({ appID: app.id, name: app.attributes.name, bundle,
    builds: builds.map(b => ({ id: b.id, build: b.attributes.version, state: b.attributes.processingState,
      expires: b.attributes.expirationDate, expired: b.attributes.expired })) }));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
