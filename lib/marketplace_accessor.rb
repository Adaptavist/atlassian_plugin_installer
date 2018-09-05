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
            details = get_plugin_details_for_version(plugin_key, plugin_version)
            plugin_build_number = details['buildNumber']
            raise "Can not find build number for plugin #{plugin_key} #{plugin_version}" unless plugin_build_number
            plugin_build_number
        end

        def get_plugin_details_for_version(plugin_key, plugin_version)
            puts "Getting plugin details from marketplace for #{plugin_key} and version #{plugin_version}"
            if plugin_version == "latest"
                url = "#{MARKETPLACE_ADDONS_URL}/#{plugin_key}/versions/latest"
            else
                url = "#{MARKETPLACE_ADDONS_URL}/#{plugin_key}/versions/name/#{plugin_version}?limit"
            end
            make_get_request(url)
        end

        # returns list of versions for plugin
        def get_plugin_versions(plugin_key, offset=0)
            result = []
            # https://marketplace.atlassian.com/rest/2/addons/com.onresolve.jira.groovy.groovyrunner/versions
            url = "#{MARKETPLACE_ADDONS_URL}/#{plugin_key}/versions?limit=50&offset=#{offset*50}"
            response = make_get_request(url)
            if response['_embedded'] and response['_embedded']['versions']
                response['_embedded']['versions'].each do |version|
                    result << version['name']
                end
            end
            result
        end

        # Plugin details contains:
          # "compatibilities": [
          #   {
          #     "application": "jira",
          #     "hosting": {
          #       "server": {
          #         "min": {
          #           "build": 64014,
          #           "version": "6.4"
          #         },
          #         "max": {
          #           "build": 64029,
          #           "version": "6.4.14"
          #         }
          #       }
          #     }
          #   }
          # ]
        def get_compatible_plugin_build_number_for_atlassian_product_version(plugin_key, product_version, product_name="jira", product_hosting="server")
            puts "Seraching for compatible plugin version for plugin #{plugin_key} and product version #{product_version}"
            required_version = Gem::Version.new(product_version)
            # test max last 500 versions
            (0..10).each do |offset|
                get_plugin_versions(plugin_key, offset).each do |version|
                    puts "Inspecting #{plugin_key} version #{version}"
                    version_details = get_plugin_details_for_version(plugin_key, version)
                    compatibilities = version_details['compatibilities']
                    puts "Version details:" + compatibilities.inspect
                    if compatibilities
                        compatibilities.each do |comp|
                            puts "Comp: "+ comp.inspect
                            if ( version_details['status'] == 'public' and comp['application'] and comp['application'] == product_name and comp['hosting'] and comp['hosting'][product_hosting])
                                compatibility_with = comp['hosting'][product_hosting]
                                min_version = compatibility_with["min"]["version"]
                                max_version = compatibility_with["max"]["version"]
                                if (Gem::Version.new(max_version) >= required_version and 
                                    Gem::Version.new(min_version) <= required_version)
                                    # add condition and dont break if searching for the highest
                                    # if found return the buildNumber
                                    return version_details['buildNumber']
                                end
                            end
                        end
                    end
                end
            end
            nil
        end

        private

        def make_get_request(url)
            uri = URI(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = url.start_with? "https"
            request = Net::HTTP::Get.new(uri.request_uri)
            request.basic_auth(@marketplace_username, @marketplace_password)
            response = http.request(request)
            JSON.parse(response.body)
        end
    end
end
