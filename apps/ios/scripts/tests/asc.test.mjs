import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { createToken, internalGroupBody, validateGroup, validateTester, apiURL } from '../asc.mjs';

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
