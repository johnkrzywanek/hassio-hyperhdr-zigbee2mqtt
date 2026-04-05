#!/usr/bin/env bashio

bashio::log.info "Preparing to start HyperHDR Zigbee2MQTT..."

bashio::config.require 'data_path'

export ZIGBEE2MQTT_DATA="$(bashio::config 'data_path')"
mkdir -p "$ZIGBEE2MQTT_DATA" || bashio::exit.nok "Could not create $ZIGBEE2MQTT_DATA"

if bashio::config.has_value 'watchdog'; then
    export Z2M_WATCHDOG="$(bashio::config 'watchdog')"
    bashio::log.info "Enabled Zigbee2MQTT watchdog with value '$Z2M_WATCHDOG'"
fi

export NODE_PATH=/app/node_modules
export ZIGBEE2MQTT_CONFIG_FRONTEND_ENABLED='true'
export ZIGBEE2MQTT_CONFIG_FRONTEND_PORT='8099'
export ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_ENABLED='true'
export Z2M_ONBOARD_URL='http://0.0.0.0:8099'

# Export mqtt and serial config sections as environment variables
function export_config() {
    local key=${1}
    local subkey

    if bashio::config.is_empty "${key}"; then
        return
    fi

    for subkey in $(bashio::jq "$(bashio::config "${key}")" 'keys[]'); do
        export "ZIGBEE2MQTT_CONFIG_$(bashio::string.upper "${key}")_$(bashio::string.upper "${subkey}")=$(bashio::config "${key}.${subkey}")"
    done
}

export_config 'mqtt'
export_config 'serial'

export TZ="$(bashio::supervisor.timezone)"

# Auto-configure MQTT from the Mosquitto add-on if no manual MQTT config provided
if (bashio::config.is_empty 'mqtt' || ! (bashio::config.has_value 'mqtt.server' || bashio::config.has_value 'mqtt.user' || bashio::config.has_value 'mqtt.password')) && bashio::var.has_value "$(bashio::services 'mqtt')"; then
    if bashio::var.true "$(bashio::services 'mqtt' 'ssl')"; then
        export ZIGBEE2MQTT_CONFIG_MQTT_SERVER="mqtts://$(bashio::services 'mqtt' 'host'):$(bashio::services 'mqtt' 'port')"
    else
        export ZIGBEE2MQTT_CONFIG_MQTT_SERVER="mqtt://$(bashio::services 'mqtt' 'host'):$(bashio::services 'mqtt' 'port')"
    fi
    export ZIGBEE2MQTT_CONFIG_MQTT_USER="$(bashio::services 'mqtt' 'username')"
    export ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD="$(bashio::services 'mqtt' 'password')"
fi

bashio::log.info "Starting HyperHDR Zigbee2MQTT..."
cd /app
exec node index.js
