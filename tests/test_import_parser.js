'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const source = fs.readFileSync(path.join(__dirname,
	'../htdocs/luci-static/resources/nezha-agent/import-parser.js'), 'utf8');
const baseclass = { extend: value => value };
const parser = Function('baseclass', source)(baseclass);

function parse(command) {
	return parser.parseInstallCommand(command);
}

let result = parse('curl -L https://example/agent.sh -o agent.sh && env ' +
	'NZ_SERVER=monitor.example.com:5555 NZ_TLS=true NZ_CLIENT_SECRET=secret ' +
	'NZ_UUID=12345678-1234-1234-1234-123456789abc ./agent.sh');
assert.deepStrictEqual(result, {
	server: 'monitor.example.com:5555',
	clientSecret: 'secret',
	tls: '1',
	hasUUID: true,
	uuid: '12345678-1234-1234-1234-123456789abc'
});

result = parse("env NZ_CLIENT_SECRET='secret value' ignored=x " +
	'NZ_SERVER="host.example:443" NZ_TLS=0 ./agent.sh');
assert.strictEqual(result.server, 'host.example:443');
assert.strictEqual(result.clientSecret, 'secret value');
assert.strictEqual(result.tls, '0');
assert.strictEqual(result.hasUUID, false);
assert.strictEqual(result.uuid, '');

result = parse("NZ_SERVER=first NZ_SERVER=last NZ_CLIENT_SECRET='a'\\''b' ./agent.sh");
assert.strictEqual(result.server, 'last');
assert.strictEqual(result.clientSecret, "a'b");

result = parse('env NZ_SERVER=host NZ_CLIENT_SECRET="path\\\\value" ./agent.sh');
assert.strictEqual(result.clientSecret, 'path\\value');

assert.throws(() => parse('env NZ_SERVER=host ./agent.sh'), /missing required/);
assert.throws(() => parse('env NZ_CLIENT_SECRET=secret ./agent.sh'), /missing required/);
assert.throws(() => parse('env NZ_SERVER=host NZ_CLIENT_SECRET=secret NZ_TLS=maybe ./agent.sh'), /invalid tls/);
assert.throws(() => parse("env NZ_SERVER='host NZ_CLIENT_SECRET=secret"), /unterminated quote/);
assert.throws(() => parse('env NZ_SERVER=host NZ_CLIENT_SECRET=secret NZ_UUID="bad id"'), /invalid uuid/);

console.log('import parser tests passed');
