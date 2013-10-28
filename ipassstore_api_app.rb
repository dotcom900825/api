require 'sinatra/namespace'
require 'sinatra/base'
require 'active_record'
require './model/pass'
require './model/pass_template'
require './model/device'
require './model/device_pass'
require './model/log'
require 'json'

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql2",
  :host     => "localhost",
  :username => "root",
  :password => "",
  :database => "ipassstore_dev"
)

class IpassstoreApiApp < Sinatra::Base
  register Sinatra::Namespace

  get '/passes/:pass_id' do
    begin
      @pass_template = PassTemplate.find(params[:pass_id])
    rescue ActiveRecord::RecordNotFound => e
      status 404 and return if @pass_template.nil?
    end

    #To do:  redirect to passbook unfound page
    last_modified(@pass_template.updated_at)

    send_file(@pass_template.pkpass_path,
              filename: "pass.pkpass",
              type: "application/vnd.apple.pkpass",
              disposition: 'attachment')

  end

  namespace "/passbook/v1" do
    get '/passes/:pass_type_identifier/:serial_number' do
      raise Sinatra::NotFound unless params[:pass_type_identifier].match /([\w\d]\.?)+/
      pass = Pass.where(pass_type_identifier: params[:pass_type_identifier], serial_number: params[:serial_number]).first

      #Not found
      status 404 and return if pass.nil?
      #Unauthorized
      status 401 and return if request.env['HTTP_AUTHORIZATION'] != "ApplePass #{pass.authentication_token}"

      @pass_template = pass.pass_template

      last_modified(@pass_template.updated_at)

      send_file(@pass_template.pkpass_path,
                filename: "pass.pkpass",
                type: "application/vnd.apple.pkpass",
                disposition: 'attachment')
    end

    get '/devices/:device_library_identifier/registrations/:pass_type_identifier' do
      begin
        @passes = Pass.joins(:devices).where('passes.pass_type_identifier = ?', params[:pass_type_identifier]).where('devices.device_library_identifier = ?', params[:device_library_identifier])
      rescue ActiveRecord::RecordNotFound => e
        status 404 and return if passes.empty?
      end

      @passes = passes.where('passes.updated_at > ?', params[:passesUpdatedSince]) if params[:passesUpdatedSince]

      if @passes.any?
        content_type :json
        {
          lastUpdated: @passes.collect(&:updated_at).max,
          serialNumbers: @passes.collect(&:serial_number).collect(&:to_s)
        }.to_json

        status 200
      else
        status 204
      end
    end

    post '/devices/:device_library_identifier/registrations/:pass_type_identifier/:serial_number' do

      puts ''
      puts "Handling registration request..."
      # validate that the request is authorized to deal with the pass referenced
      puts "#<RegistrationRequest device_id: #{params[:device_library_identifier]}, pass_type_id: #{params[:pass_type_identifier]}, serial_number: #{params[:serial_number]}, authentication_token: #{authentication_token}, push_token: #{push_token}>"
      puts ''

      @pass = Pass.where(pass_type_identifier: params[:pass_type_identifier], serial_number: params[:serial_number]).first_or_initialize
      @pass.save

      status 404 and return if @pass.nil?
      status 401 and return if request.env['HTTP_AUTHORIZATION'] != "ApplePass #{@pass.authentication_token}"

      @device = @pass.devices.where(device_library_identifier: params[:device_library_identifier]).first_or_initialize
      @device.push_token = push_token
      @pass.devices << @device

      @device.save

      status 200
    end

    delete '/devices/:device_library_identifier/registrations/:pass_type_identifier/:serial_number' do
      begin
        @pass = Pass.where(pass_type_identifier: params[:pass_type_identifier], serial_number: params[:serial_number]).first
      rescue ActiveRecord::RecordNotFound => e
        status 404 and return if @pass.empty?
      end

      status 401 and return if request.env['HTTP_AUTHORIZATION'] != "ApplePass #{@pass.authentication_token}"

      begin
        @device = @pass.devices.where(device_library_identifier: params[:device_library_identifier]).first
      rescue ActiveRecord::RecordNotFound => e
        status 404 and return if @device.empty?
      end

      @device.destroy
      status 200
    end

    private

    def authentication_token
      if env && env['HTTP_AUTHORIZATION']
        env['HTTP_AUTHORIZATION'].split(" ").last
      end
    end

    # Convienience method for parsing the pushToken out of a JSON POST body
    def push_token
      if request && request.body
        request.body.rewind
        json_body = JSON.parse(request.body.read)
        if json_body['pushToken']
          json_body['pushToken']
        end
      end
    end

  end

end
