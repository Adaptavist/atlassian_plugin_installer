require 'uri'
require 'json'
require 'net/http'
require 'net/https'

module AtlassianPluginInstaller
    class MarketplaceAccessor
        MARKETPLACE_URL = "https://marketplace.atlassian.com"
        MARKETPLACE_ADDONS_URL = "#{MARKETPLACE_URL}/rest/2/addons"

        def initialize(marketplace_username, marketplace_password)
            @marketplace_username = marketplace_username
            @marketplace_password = marketplace_password
        end

        def resolve_build_number_from_marketplace(plugin_key, plugin_version)
            puts "Getting build_number from marketplace for #{plugin_key} and version #{plugin_version}"
            if plugin_version == "latest"
                url = "#{MARKETPLACE_ADDONS_URL}/#{plugin_key}/versions/latest"
            else
                url = "#{MARKETPLACE_ADDONS_URL}/#{plugin_key}/versions/name/#{plugin_version}"
            end
            uri = URI(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = url.start_with? "https"
            request = Net::HTTP::Get.new(uri.request_uri)
            request.basic_auth(@marketplace_username, @marketplace_password)
            response = http.request(request)
            plugin_build_number = JSON.parse(response.body)['buildNumber'] # parse access token
            raise "Can not find build number for plugin #{plugin_key} #{plugin_version}" unless plugin_build_number
            plugin_build_number
        end
    end
end
