require 'active_record'

class Device < ActiveRecord::Base
  # attr_accessible :title, :body
  validates_presence_of :device_library_identifier



  has_many :device_passes, :dependent => :destroy
  has_many :passes, :through=> :device_passes

  before_destroy :clear_association

  private
  def clear_association
    self.device_passes.clear
  end
end
