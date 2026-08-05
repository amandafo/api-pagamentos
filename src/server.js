'use strict';

const http = require('node:http');
const crypto = require('node:crypto');

const payments = new Map();
const idempotencyKeys = new Map();

function send(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
}

async function readJson(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 16_384) throw Object.assign(new Error('payload muito grande'), { status: 413 });
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw Object.assign(new Error('JSON invalido'), { status: 400 });
  }
}

function validPayment(body) {
  return body && Number.isInteger(body.amount) && body.amount > 0 &&
    typeof body.currency === 'string' && /^[A-Z]{3}$/.test(body.currency) &&
    typeof body.description === 'string' && body.description.length <= 140;
}

async function handler(req, res) {
  const requestId = req.headers['x-request-id'] || crypto.randomUUID();
  res.setHeader('x-request-id', requestId);

  if (req.method === 'GET' && req.url === '/health') {
    return send(res, 200, { status: 'ok' });
  }

  if (req.method === 'POST' && req.url === '/v1/payments') {
    const key = req.headers['idempotency-key'];
    if (!key || key.length < 8 || key.length > 128) {
      return send(res, 400, { error: 'Idempotency-Key deve ter entre 8 e 128 caracteres', requestId });
    }
    if (idempotencyKeys.has(key)) return send(res, 200, idempotencyKeys.get(key));

    try {
      const body = await readJson(req);
      if (!validPayment(body)) {
        return send(res, 422, { error: 'amount, currency e description invalidos', requestId });
      }
      const payment = {
        id: crypto.randomUUID(),
        amount: body.amount,
        currency: body.currency,
        description: body.description,
        status: 'approved',
        createdAt: new Date().toISOString()
      };
      payments.set(payment.id, payment);
      idempotencyKeys.set(key, payment);
      return send(res, 201, payment);
    } catch (error) {
      return send(res, error.status || 500, { error: error.message, requestId });
    }
  }

  const match = req.method === 'GET' && req.url.match(/^\/v1\/payments\/([0-9a-f-]+)$/i);
  if (match) {
    const payment = payments.get(match[1]);
    return payment ? send(res, 200, payment) : send(res, 404, { error: 'pagamento nao encontrado', requestId });
  }
  return send(res, 404, { error: 'rota nao encontrada', requestId });
}

function createServer() { return http.createServer(handler); }

if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  createServer().listen(port, '0.0.0.0', () => console.log(`api-pagamentos ouvindo na porta ${port}`));
}

module.exports = { createServer };
