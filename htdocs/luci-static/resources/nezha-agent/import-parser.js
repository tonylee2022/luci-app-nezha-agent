'use strict';
'require baseclass';

function shellTokens(command) {
	var tokens = [];
	var token = '';
	var state = 'plain';
	var started = false;
	var i, ch;

	for (i = 0; i < command.length; i++) {
		ch = command.charAt(i);

		if (state === 'single') {
			if (ch === "'")
				state = 'plain';
			else
				token += ch;
			continue;
		}

		if (state === 'double') {
			if (ch === '"') {
				state = 'plain';
			} else if (ch === '\\') {
				var next;

				if (++i >= command.length)
					throw new Error('unterminated escape');
				next = command.charAt(i);
				if (next === '\n')
					continue;
				token += /[$`"\\]/.test(next) ? next : '\\' + next;
			} else {
				token += ch;
			}
			continue;
		}

		if (/\s/.test(ch)) {
			if (started) {
				tokens.push(token);
				token = '';
				started = false;
			}
		} else if (ch === "'") {
			state = 'single';
			started = true;
		} else if (ch === '"') {
			state = 'double';
			started = true;
		} else if (ch === '\\') {
			if (++i >= command.length)
				throw new Error('unterminated escape');
			token += command.charAt(i);
			started = true;
		} else if (/[;&|()]/.test(ch)) {
			if (started) {
				tokens.push(token);
				token = '';
				started = false;
			}
		} else {
			token += ch;
			started = true;
		}
	}

	if (state !== 'plain')
		throw new Error('unterminated quote');
	if (started)
		tokens.push(token);

	return tokens;
}

function parseInstallCommand(command) {
	var values = {};
	var names = {
		NZ_SERVER: true,
		NZ_CLIENT_SECRET: true,
		NZ_TLS: true,
		NZ_UUID: true
	};

	shellTokens(command).forEach(function(token) {
		var pos = token.indexOf('=');
		var name;

		if (pos < 1)
			return;
		name = token.substring(0, pos);
		if (names[name])
			values[name] = token.substring(pos + 1);
	});

	if (!values.NZ_SERVER || !values.NZ_CLIENT_SECRET)
		throw new Error('missing required values');

	if (values.NZ_TLS != null) {
		switch (values.NZ_TLS.toLowerCase()) {
		case '1':
		case 'true':
			values.NZ_TLS = '1';
			break;
		case '0':
		case 'false':
			values.NZ_TLS = '0';
			break;
		default:
			throw new Error('invalid tls value');
		}
	}

	if (values.NZ_UUID != null && /[\s\x00-\x1f\x7f]/.test(values.NZ_UUID))
		throw new Error('invalid uuid value');

	return {
		server: values.NZ_SERVER,
		clientSecret: values.NZ_CLIENT_SECRET,
		tls: values.NZ_TLS,
		hasUUID: values.NZ_UUID != null,
		uuid: values.NZ_UUID || ''
	};
}

return baseclass.extend({
	parseInstallCommand: parseInstallCommand
});
