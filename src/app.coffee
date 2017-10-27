Promise = require 'bluebird'
rp = require 'request-promise'
_ = require 'lodash'
fs = require 'fs'

options = {
	method: 'GET',
	uri: process.env.RESIN_SUPERVISOR_ADDRESS + '/v1/dependent',
	qs: {
		apikey: process.env.RESIN_SUPERVISOR_API_KEY
	},
	body: {},
	headers: {
		'Content-Type': 'application/json'
	},
	json: true
}

get_applications = () ->
	application_options = _.clone(options)
	application_options.uri += '/application'
	rp(application_options)
	.then (applications) ->
		return applications

get_devices = () ->
	device_options = _.clone(options)
	device_options.uri += '/device'
	rp(device_options)
	.then (devices) ->
		return devices

get_firmware = (device) ->
	firmware_options = _.clone(options)
	firmware_options.uri += '/application/' + device.appId + '/update/asset/' + device.targetCommit
	rp(firmware_options)
	.on 'response', (res) ->
		res.pipe(fs.createWriteStream( '/tmp/firmware.tar'))
	.on 'finish', () ->
		return '/tmp/firmware.tar'

post_online_devices = (online_devices) ->
	scan_options = _.clone(options)
	scan_options.method = 'POST'
	scan_options.uri += ('/application/' + online_devices.appId + '/scan')
	scan_options.body = online_devices.body
	rp(scan_options)

patch_device = (device, body) ->
	patch_options = _.clone(options)
	patch_options.method = 'PATCH'
	patch_options.uri += '/device/' + device.uuid
	patch_options.body = body
	rp(patch_options)

# Adapter scan function
scan_online_devices = (application) ->
	mock_results = {
		appId: application.appId,
		body: {
			device_type: 'generic',
			online_devices: [
				'device_1',
				'device_2'
			],
			expiry_date: _.now() + 5 * 60000
		}
	}

	return mock_results

# Adapter update function
update_online_device = (device, firmware) ->
	Promise.resolve()

# Main loop
start = () ->
	get_applications()
	.then (applications) ->
		console.log('Applications: ', JSON.stringify(applications))
		_.map(applications, scan_online_devices)
	.then (online_devices) ->
		console.log('Online devices: ', JSON.stringify(online_devices))
		_.map(online_devices, post_online_devices)
	.then ->
		get_devices()
	.then (devices) ->
		console.log('Managed devices: ', JSON.stringify(devices))
		_.filter devices, (device) ->
			device.commit != device.targetCommit
	.then (devices_to_be_updated) ->
		console.log('Devices to be updated: ', JSON.stringify(devices_to_be_updated))
		_.map devices_to_be_updated, (device) ->
			console.log('Starting device update: ', JSON.stringify(device.uuid))
			get_firmware(device)
			.then (firmware) ->
				update_online_device(device, firmware)
			.then ->
				patch_device(device, {'commit': device.targetCommit})
			.then ->
				console.log('Finished device update: ', JSON.stringify(device.uuid))
	.then ->
		setTimeout(start, 10000)

start()
