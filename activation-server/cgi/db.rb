require 'postgres'

class UntangleKey

  def initialize
    @conn = PGconn.new('localhost', 5432, '', '', 'untangle_key',
                       'untangle_key', 'untangle_key')
  end

  def listAllKeys
    return @conn.exec(<<-eos
                      SELECT license_key || '  |  ' || ip_address || ' | ' || passphrase
                      FROM license_key,dsa_key
                      WHERE license_key.dsa_key_id = dsa_key.id
                      eos
                      )
  end

  def getNewKey(ip)
    res = @conn.exec(<<-eos
                     SELECT license_key FROM license_key
                     WHERE used=FALSE LIMIT 1
                     eos
                     )
    if not res.num_tuples == 1
      raise Exception.new("No more keys")
    else
      row = res.to_a[0]
      licenseKey = row['license_key']
      @conn.exec("UPDATE license_key SET used=TRUE, ip_address='#{ip}' WHERE license_key='#{licenseKey}'")
      return licenseKey
    end
  end

  def insertKey(licenseKey, ip)
    res = @conn.exec(<<-eos
                     SELECT * FROM license_key 
                     WHERE license_key = '#{licenseKey}'
                     AND ip_address = '#{ip}'
                     eos
                     )

    if not res.num_tuples == 1
      @conn.exec(<<-eos
                 INSERT INTO license_key (license_key, used, ip_address)
                 VALUES ('#{licenseKey}', TRUE, '#{ip}')
                 eos
                 )
    end
  end

  def getDSAKeyIDByPublicKey(publicKey)
    res = @conn.exec(<<-eos
                     SELECT id
                     FROM dsa_key
                     WHERE public_key = '#{publicKey}'
                     eos
                     )

    if not res.num_tuples == 1
      return nil
    else
      return res.to_a[0]
    end
  end

  def getDSAKeyIDByLicenseKeyID(licenseKeyID)
    res = @conn.exec(<<-eos
                     SELECT dsa_key.id
                     FROM dsa_key, license_key
                     WHERE dsa_key.id = license_key.dsa_key_id
                     AND license_key.id = '#{licenseKeyID}'
                     eos
                     )

    if not res.num_tuples == 1
      return nil
    else
      return res.to_a[0]
    end
  end

  def getLicenseKeyIDByLicenseKeyAndIP(licenseKey, ip)
    res = @conn.exec(<<-eos
                     SELECT id FROM license_key
                     WHERE license_key = '#{licenseKey}'
                     AND ip_address = '#{ip}'
                     eos
                     )

    if not res.num_tuples == 1
      return nil
    else
      return res.to_a[0]
    end
  end

  def insertLicenseKey(licenseKey, ip, dsaKeyID = 'NULL')
    @conn.exec(<<-eos
               INSERT INTO license_key (license_key, used, dsa_key_id, ip_address)
               VALUES ('#{licenseKey}',TRUE, #{dsaKeyID}, '#{ip}')
               eos
               )
    return getLicenseKeyIDByLicenseKeyAndIP(licenseKey, ip)
  end

  def updateDsaKey(dsaKeyID, licenseKeyID, privateKey, publicKey, passphrase)
    @conn.exec(<<-eos
               UPDATE dsa_key
               SET private_key = '#{privateKey}',
                   public_key = '#{publicKey}',
                   passphrase = '#{passphrase}',
                   date_issued = now()
               WHERE id = #{dsaKeyID}
               eos
               )
    updateLicenseTable(licenseKeyID, dsaKeyID)
  end

  def insertDsaKey(licenseKeyID, privateKey, publicKey, passphrase)
    @conn.exec(<<-eos
               INSERT INTO dsa_key (private_key, public_key, passphrase)
               VALUES ('#{privateKey}', '#{publicKey}', '#{passphrase}')
               eos
               )
    updateLicenseTable(licenseKeyID, getDSAKeyIDByPublicKey(publicKey))
  end

  def updateLicenseTable(licenseKeyID, dsaKeyID)
    # setting "used = TRUE" for a key that was already in the 
    # table is only needed for testing purposes; in real life, 
    # those keys should have been activated through the other
    # CGI and "used" should already be TRUE.
    @conn.exec(<<-eos
               UPDATE license_key
               SET dsa_key_id = #{dsaKeyID}, used = TRUE
               WHERE id = '#{licenseKeyID}'
               eos
               )
  end

  def getAllPublicKeys
    return @conn.exec("SELECT public_key FROM dsa_key")
  end

  def close
    @conn.close
  end

end
