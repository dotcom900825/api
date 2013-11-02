require 'sinatra/namespace'
require 'sinatra/base'
require 'active_record'
require './model/pass'
require './model/pass_template'
require './model/device'
require './model/device_pass'
require './model/log'

configure :development do
  ActiveRecord::Base.establish_connection(
    :adapter  => "mysql2",
    :host     => "localhost",
    :username => "root",
    :password => "",
    :database => "ipassstore_dev"
  )
end

configure :production do
  ActiveRecord::Base.establish_connection(
    :adapter  => "mysql2",
    :host     => "localhost",
    :username => "root",
    :password => "",
    :database => "ipassstore_production"
  )
end

class IpassstoreApiApp < Sinatra::Base
  register Sinatra::Namespace

  configure do
    enable :logging
    file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::ShowExceptions
    use Rack::CommonLogger, file
  end

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

      pt = PassTemplate.where(pass_type_identifier: params[:pass_type_identifier]).first
      pass = Pass.where(serial_number: params[:serial_number]).first

      #Not found
      status 404 and return if pass.nil?
      #Unauthorized
      status 401 and return if request.env['HTTP_AUTHORIZATION'] != "ApplePass #{pt.authentication_token}"

      last_modified(pt.updated_at)

      send_file(pt.pkpass_path,
                filename: "pass.pkpass",
                type: "application/vnd.apple.pkpass",
                disposition: 'attachment')
    end

    get '/devices/:device_library_identifier/registrations/:pass_type_identifier' do
      begin
        pt = PassTemplate.where(pass_type_identifier: params[:pass_type_identifier]).first
      rescue ActiveRecord::RecordNotFound => e
        status 404 and return if pt
      end

      if pt.is_public_card?
        if pt.last_updated > params[:passesUpdatedSince]
          content_type :json
          {
            lastUpdated: pt.last_updated,
            serialNumbers: pt.passes.collect(&:serial_number).collect(&:to_s)
          }.to_json
        else
          status 204
        end

      else
        passes = Pass.joins(:pass_templates).where('pass_templates.pass_type_identifier = ?', params[:pass_type_identifier]).joins(:devices).where('devices.device_library_identifier = ?', params[:device_library_identifier])
        passes = passes.where('passes.updated_at > ?', params[:passesUpdatedSince]) if params[:passesUpdatedSince]
        if @passes.any?
          content_type :json
          {
            lastUpdated: @passes.collect(&:updated_at).max,
            serialNumbers: @passes.collect(&:serial_number).collect(&:to_s)
          }.to_json
        else
          status 204
        end

      end
    end

    post '/devices/:device_library_identifier/registrations/:pass_type_identifier/:serial_number' do

      puts ''
      puts "Handling registration request..."
      # validate that the request is authorized to deal with the pass referenced
      puts "#<RegistrationRequest device_id: #{params[:device_library_identifier]}, pass_type_id: #{params[:pass_type_identifier]}, serial_number: #{params[:serial_number]}, authentication_token: #{authentication_token}, push_token: #{push_token}>"
      puts ''

      pt = PassTemplate.where(pass_type_identifier: params[:pass_type_identifier]).first
      @pass = Pass.where(serial_number: params[:serial_number]).first_or_initialize
      @pass.pass_template = pt
      @pass.save

      status 404 and return if @pass.nil?
      status 401 and return if request.env['HTTP_AUTHORIZATION'] != "ApplePass #{pt.authentication_token}"

      @device = @pass.devices.where(device_library_identifier: params[:device_library_identifier]).first_or_initialize
      @device.push_token = push_token
      @pass.devices << @device

      @device.save

      status 200
    end

    delete '/devices/:device_library_identifier/registrations/:pass_type_identifier/:serial_number' do
      begin
        pt = PassTemplate.where(pass_type_identifier: params[:pass_type_identifier]).first
        @pass = pt.passes.where(serial_number: params[:serial_number]).first
      rescue ActiveRecord::RecordNotFound => e
        status 404 and return if @pass.empty?
      end

      status 401 and return if request.env['HTTP_AUTHORIZATION'] != "ApplePass #{pt.authentication_token}"

      begin
        @device = @pass.devices.where(device_library_identifier: params[:device_library_identifier]).first
      rescue ActiveRecord::RecordNotFound => e
        status 404 and return if @device.empty?
      end

      @device.destroy
      status 200
    end

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


