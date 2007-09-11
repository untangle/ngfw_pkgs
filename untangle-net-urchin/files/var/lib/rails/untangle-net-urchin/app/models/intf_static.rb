class IntfStatic < ActiveRecord::Base
  belongs_to :interface
  
  has_and_belongs_to_many :ip_networks

  has_and_belongs_to_many :nat_policies

  protected
  def validate
    
  end
end
