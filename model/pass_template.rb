require 'active_record'

require 'dubai'
require 'qr4r'
require 'json'

class PassTemplate < ActiveRecord::Base
  belongs_to :organization
  has_many :passes

  PASS_ROOT = "public/passbooks"
  P12_PASSWORD = "4742488"

  PASS_TYPE = {1 => :coupon, 2 => :event_ticket, 3 => :generic_pass, 4 => :store_card}
  INVERT_PASS_TYPE = PASS_TYPE.invert

  PASS_DISTRIBUTION = { 1 => :public, 2 => :private}
  INVERT_PASS_DISTRIBUTION = PASS_DISTRIBUTION.invert


  def is_public_card?
    return true if self.distribution_type == INVERT_PASS_DISTRIBUTION[:public]
    false
  end

  def pkpass_path
    "#{passbook_path}/#{slug}.pkpass"
  end

  def get_pass_type_identifier
    parse_json["passTypeIdentifier"]
  end

  def get_auth_token
    parse_json["authenticationToken"]
  end

  private

  def parse_json
    JSON.parse(File.read("#{pkpass_packet_path}/pass.json"))
  end

  def passbook_path
    "#{PASS_ROOT}/#{slug}"
  end

  def p12_path
    "#{passbook_path}/certificate.p12"
  end

  def p12_pw
    P12_PASSWORD
  end

  def pkpass_packet_path
    "#{passbook_path}/#{slug}.pass"
  end
end
