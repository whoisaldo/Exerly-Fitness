import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { createToken, internalGroupBody, validateGroup, validateTester, apiURL, requiredCapabilityBodies, supportsRequiredCapabilities, profileFits, provisionTargets } from '../asc.mjs';

test('ASC JWT is a short-lived ES256 token without exposing the private key', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const token = createToken(privateKey, 'SYNTHETIC', 'synthetic-issuer', 1000);
  const [header, body, signature] = token.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url')), { alg: 'ES256', kid: 'SYNTHETIC', typ: 'JWT' });
  assert.deepEqual(JSON.parse(Buffer.from(body, 'base64url')), {
    iss: 'synthetic-issuer', iat: 1000, exp: 1600, aud: 'appstoreconnect-v1',
  });
  assert(verify('sha256', Buffer.from(`${header}.${body}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(signature, 'base64url')));
});

test('internal group cannot enable a public link or auto-add future builds', () => {
  const body = internalGroupBody('synthetic-app');
  assert.equal(body.data.attributes.isInternalGroup, true);
  assert.equal(body.data.attributes.publicLinkEnabled, false);
  assert.equal(body.data.attributes.hasAccessToAllBuilds, false);
  validateGroup(body.data);
  for (const attributes of [{ isInternalGroup: false }, { publicLinkEnabled: true }, { hasAccessToAllBuilds: true }]) {
    assert.throws(() => validateGroup({ attributes: { ...body.data.attributes, ...attributes } }));
  }
});

test('internal group members must match the account holder and use email invitations', () => {
  const tester = { attributes: { email: 'owner@example.test', inviteType: 'EMAIL' } };
  validateTester(tester, 'owner@example.test');
  assert.throws(() => validateTester(tester, 'someone@example.test'));
  assert.throws(() => validateTester({ attributes: { ...tester.attributes, inviteType: 'PUBLIC_LINK' } }, 'owner@example.test'));
});

test('API token can only go to the ASC origin, including pagination', () => {
  assert.equal(apiURL('/v1/apps').origin, 'https://api.appstoreconnect.apple.com');
  assert.throws(() => apiURL('https://example.test/v1/apps'));
  assert.throws(() => apiURL('//example.test/v1/apps'));
  assert.throws(() => apiURL('http://api.appstoreconnect.apple.com/v1/apps'));
});

test('provisioning selects only profiles that include native Apple sign-in and HealthKit', () => {
  const valid = { 'com.apple.developer.healthkit': true, 'com.apple.developer.applesignin': ['Default'] };
  assert.equal(supportsRequiredCapabilities(valid), true);
  for (const value of [undefined, [], ['Other'], 'Default']) {
    assert.equal(supportsRequiredCapabilities({ ...valid, 'com.apple.developer.applesignin': value }), false);
  }
  assert.equal(supportsRequiredCapabilities({ ...valid, 'com.apple.developer.healthkit': false }), false);
});

test('Apple sign-in provisioning configures Exerly as its own primary app', () => {
  const requests = requiredCapabilityBodies('synthetic-bundle');
  assert.deepEqual(requests.map(r => r.data.attributes.capabilityType), ['HEALTHKIT', 'APPLE_ID_AUTH']);
  assert(requests.every(r => r.data.relationships.bundleId.data.id === 'synthetic-bundle'));
  assert.deepEqual(requests[1].data.attributes.settings, [
    { key: 'APPLE_ID_AUTH_APP_CONSENT', options: [{ key: 'PRIMARY_APP_CONSENT', enabled: true }] }
  ]);
});

test('each provisioning target accepts only a profile for its own bundle and capabilities', () => {
  const app = { 'application-identifier': '9X79V37Q89.com.exerly.fitness', 'com.apple.developer.healthkit': true,
    'com.apple.developer.applesignin': ['Default'] };
  const widgets = { 'application-identifier': '9X79V37Q89.com.exerly.fitness.widgets' };
  assert.equal(profileFits(provisionTargets.app, app), true);
  assert.equal(profileFits(provisionTargets.app, { ...app, 'com.apple.developer.healthkit': null }), false);
  assert.equal(profileFits(provisionTargets.widgets, widgets), true);
  assert.equal(profileFits(provisionTargets.widgets, app), false);
  assert.equal(profileFits(provisionTargets.app, widgets), false);
  assert.deepEqual(requiredCapabilityBodies('X', provisionTargets.widgets.capabilities), []);
});
