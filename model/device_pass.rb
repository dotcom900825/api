require 'active_record'

class DevicePass < ActiveRecord::Base
  # attr_accessible :title, :body
  validates :device_id, :pass_id, presence: true
  belongs_to :device
  belongs_to :pass
end
