require 'active_record'

class Pass < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :pass_template

  has_many :user_passes
  has_many :users, :through=>:user_passes

  has_many :device_passes
  has_many :devices, :through=>:device_passes

  validates_uniqueness_of :serial_number


end
