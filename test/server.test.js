'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');

let server;
let baseUrl;

before(async () => {
  server = createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});
after(() => new Promise(resolve => server.close(resolve)));

test('health check', async () => {
  const response = await fetch(`${baseUrl}/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok' });
});

test('cria pagamento e respeita idempotencia', async () => {
  const options = {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'idempotency-key': 'pedido-0001' },
    body: JSON.stringify({ amount: 1590, currency: 'BRL', description: 'pedido 1' })
  };
  const first = await fetch(`${baseUrl}/v1/payments`, options);
  assert.equal(first.status, 201);
  const payment = await first.json();
  const second = await fetch(`${baseUrl}/v1/payments`, options);
  assert.equal(second.status, 200);
  assert.equal((await second.json()).id, payment.id);
});

test('rejeita pagamento invalido', async () => {
  const response = await fetch(`${baseUrl}/v1/payments`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'idempotency-key': 'pedido-0002' },
    body: JSON.stringify({ amount: -1, currency: 'real', description: 'invalido' })
  });
  assert.equal(response.status, 422);
});
