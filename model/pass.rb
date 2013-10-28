require 'active_record'

class Pass < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :pass_template

  has_many :user_passes
  has_many :users, :through=>:user_passes

  has_many :device_passes
  has_many :devices, :through=>:device_passes

  validates_presence_of :pass_type_identifier, :serial_number
  validates_uniqueness_of :pass_type_identifier
  validates_uniqueness_of :serial_number, scope: :pass_type_identifier


end
