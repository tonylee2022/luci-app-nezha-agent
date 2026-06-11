'use strict';
'require form';
'require rpc';
'require view';

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: [ 'name' ],
	expect: { '': {} }
});

function getServiceStatus() {
	return L.resolveDefault(callServiceList('nezha-agent'), {}).then(function(res) {
		var instances = res['nezha-agent'] && res['nezha-agent'].instances;
		var running = false;

		Object.keys(instances || {}).forEach(function(name) {
			running = running || instances[name].running === true;
		});

		return running;
	});
}

return view.extend({
	load: function() {
		return getServiceStatus();
	},

	render: function(running) {
		var m, s, o;

		m = new form.Map('nezha-agent', _('Nezha Agent'),
			'配置并管理哪吒监控 Agent。');

		s = m.section(form.NamedSection, 'main', 'agent', _('Agent Settings'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.DummyValue, '_status', _('Service status'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			return running
				? '<strong style="color:green">%s</strong>'.format(_('Running'))
				: '<strong style="color:red">%s</strong>'.format(_('Not running'));
		};

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.rmempty = false;

		o = s.option(form.Value, 'config_file', _('Configuration file'));
		o.default = '/etc/nezha-agent/config.yml';
		o.datatype = 'file';
		o.rmempty = false;

		o = s.option(form.Value, 'server', _('Dashboard server'));
		o.description = '哪吒面板服务器地址，格式为 主机:端口。';
		o.placeholder = 'monitor.example.com:5555';
		o.rmempty = false;

		o = s.option(form.Value, 'client_secret', _('Client secret'));
		o.password = true;
		o.rmempty = false;

		o = s.option(form.Flag, 'tls', _('Enable TLS'));
		o.default = '0';

		o = s.option(form.Flag, 'insecure_tls', _('Skip TLS verification'));
		o.depends('tls', '1');

		o = s.option(form.Flag, 'disable_auto_update', _('Disable agent auto-update'));
		o.default = '0';

		o = s.option(form.Flag, 'disable_force_update', _('Disable forced updates'));

		o = s.option(form.Flag, 'disable_command_execute', _('Disable remote command execution'));

		o = s.option(form.Flag, 'disable_nat', _('Disable NAT traversal'));

		o = s.option(form.Flag, 'disable_send_query', _('Disable network query tasks'));

		o = s.option(form.Value, 'report_delay', _('Report interval'));
		o.datatype = 'range(1,4)';
		o.default = '3';
		o.description = '状态上报间隔，单位为秒，可设置为 1 到 4。';

		o = s.option(form.DynamicList, 'custom_ip_api', _('Custom IP APIs'));
		o.datatype = 'url';
		o.rmempty = true;
		o.placeholder = 'https://api.example.com/ip';
		o.description = _('Add the API domains to the direct-connect rules of OpenClash, PassWall, or other proxy software to obtain the real public IP address.');

		return m.render();
	}
});
