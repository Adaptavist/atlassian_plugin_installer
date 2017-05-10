require 'uri'
require 'json'
require 'net/http'
require 'net/https'

module AtlassianPluginInstaller
    class AtlassianPluginInstaller

        def initialize(application_url, admin_username, admin_password)
            @application_url = application_url
            @admin_username = admin_username
            @admin_password = admin_password
        end

        def fetch_application_access_token
            url = "#{@application_url}/rest/plugins/1.0/?os_authType=basic"
            uri = URI(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = url.start_with? "https"
            request = Net::HTTP::Get.new(uri.request_uri)
            request.initialize_http_header({"Accept" => "application/vnd.atl.plugins.installed+json"})
            request.basic_auth(@admin_username, @admin_password)
            response = http.request(request)
            return response.code, response['upm-token'] # parse access token
        end

        # Installs plugin
        # curl -i -H "Accept: application/json" -H "Content-Type: application/vnd.atl.plugins.install.uri+json" 
        # -X POST -u admin -d '{"pluginUri":"https://marketplace.atlassian.com/download/plugins/com.onresolve.jira.groovy.groovyrunner/version/1001120"}' 
        # https://avst-test1129.dyn.adaptavist.com//rest/plugins/1.0/?token=-6906413003836887391
        def install_plugin(plugin_key, plugin_build_number, token)
            puts "Installing plugin #{plugin_key}"
            plugin_uri = "https://marketplace.atlassian.com/download/plugins/#{plugin_key}/version/#{plugin_build_number}"
            url = "#{@application_url}/rest/plugins/1.0/?token=#{token}"
            body = {
               "pluginUri" => plugin_uri
            }.to_json
            uri = URI.parse(url)
            https = Net::HTTP.new(uri.host,uri.port)
            https.use_ssl = url.start_with? "https"
            req = Net::HTTP::Post.new("#{uri.request_uri}")
            req.basic_auth(@admin_username, @admin_password)
            req.body = body
            req['Accept'] = 'application/json'
            req['Content-Type'] = 'application/vnd.atl.plugins.install.uri+json'    
            res = https.request(req)
            puts "Install plugin response: #{res.inspect}"
            res
        end

        def installation_completed(plugin_key, retries=10, sleep_time=10)
            puts "Waiting until the plugin gets installed"
            completed = false
            for i in (0..retries) do
                url = "#{@application_url}/rest/plugins/1.0/#{plugin_key}-key/summary"
                uri = URI(url)
                http = Net::HTTP.new(uri.host, uri.port)
                http.use_ssl = url.start_with? "https"
                request = Net::HTTP::Get.new(uri.request_uri)
                request.initialize_http_header({"Accept" => "application/vnd.atl.plugins+json"})
                request.basic_auth(@admin_username, @admin_password)

                response = http.request(request)
                if response.code == '200'
                    puts "Installation completed..."
                    completed = true
                    break
                end
                puts "Fetching #{url}"
                puts "Response was #{response.inspect}"
                puts "Installation still not done, sleeping for #{sleep_time}, retry #{i}/#{retries}"
                sleep(sleep_time)
            end
            completed
        end

        def install_license(plugin_key, license)
            puts "Installing license"
            url = "#{@application_url}/rest/plugins/1.0/#{plugin_key}-key/license"
            body = {
               "rawLicense" => license
            }.to_json

            uri = URI.parse(url)
            https = Net::HTTP.new(uri.host,uri.port)
            https.use_ssl = url.start_with? "https"
            req = Net::HTTP::Put.new("#{uri.request_uri}")

            req.basic_auth(@admin_username, @admin_password)
            req.body = body
            req['Accept'] = 'application/json'
            req['Content-Type'] = "application/vnd.atl.plugins+json"
            res = https.request(req)
            puts "License response: #{res.inspect} #{res.body}"
            res
        end
    end
end
