module UvmHelper
  VpnIndex = 8
  ## Indices : 
  ## 1 -> external
  ## 3 -> DMZ
  ## 8 -> VPN
  ## 2 -> internal
  DefaultOrder = "1,3,#{VpnIndex},2"
end
