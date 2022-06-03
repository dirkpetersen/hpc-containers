#! /bin/bash

dnf install sssd sssd-tools sssd-ldap oddjob-mkhomedir -y

# cp /cm/shared/etc/sssd/conf.d/hpc-sssd.conf /etc/sssd/conf.d/

# insert weaker cipher string in /etc/pki/tls/openssl.cnf after .include statement
if ! grep '^CipherString' /etc/pki/tls/openssl.cnf > /dev/nul; then
  sed -i '/^.include \/etc\/crypto.*/a CipherString = DEFAULT@SECLEVEL=1' /etc/pki/tls/openssl.cnf
fi

systemctl restart oddjobd
systemctl stop sssd && rm -rf /var/lib/sss/db/* && systemctl restart sssd && systemctl status sssd
getent passwd

#echo "skipping PAM install"
#exit

#  configure PAM, LDAP already needs to be setup 
#if ! grep '^xxx' /etc/pam.d/password-auth > /dev/nul; then
#   sed -i '/^yyy/a zzz' /etc/pam.d/${AUTH1}-auth
#fi

echo -e "\nconfiguring PAM authentication\n"
for AUTH1 in password system; do
  # backup existing file 
  if ! [[ -f /etc/pam.d/${AUTH1}-auth.ldap ]]; then 
    echo "backing up /etc/pam.d/${AUTH1}-auth to /etc/pam.d/${AUTH1}-auth.ldap"
    cp /etc/pam.d/${AUTH1}-auth /etc/pam.d/${AUTH1}-auth.ldap
  fi
  ##### editing password-auth and systemauth ######
  if ! grep '^auth.*pam_sss.so' /etc/pam.d/${AUTH1}-auth > /dev/nul; then
    sed -i '/^auth.*pam_ldap.so/a auth        sufficient    pam_sss.so forward_pass' /etc/pam.d/${AUTH1}-auth
  fi
  if ! grep '^account.*pam_sss.so' /etc/pam.d/${AUTH1}-auth > /dev/nul; then
    sed -i '/^account.*pam_ldap.so/a account     [default=bad success=ok user_unknown=ignore] pam_sss.so' /etc/pam.d/${AUTH1}-auth
  fi
  if ! grep '^password.*pam_sss.so' /etc/pam.d/${AUTH1}-auth > /dev/nul; then
    sed -i '/^password.*pam_ldap.so/a password    sufficient    pam_sss.so use_authtok' /etc/pam.d/${AUTH1}-auth
  fi
  if ! grep '^session.*pam_sss.so' /etc/pam.d/${AUTH1}-auth > /dev/nul; then
    sed -i '/^session.*pam_ldap.so/a session     optional      pam_sss.so' /etc/pam.d/${AUTH1}-auth
  fi
  if ! grep '^session.*pam_oddjob_mkhomedir.so' /etc/pam.d/${AUTH1}-auth > /dev/nul; then
    sed -i '/^-session.*pam_systemd.so/a session     optional      pam_oddjob_mkhomedir.so umask=0077' /etc/pam.d/${AUTH1}-auth
  fi
  # copy of new file 
  if ! [[ -f /etc/pam.d/${AUTH1}-auth.sss ]]; then
    echo "coping new config /etc/pam.d/${AUTH1}-auth to /etc/pam.d/${AUTH1}-auth.sss"
    cp /etc/pam.d/${AUTH1}-auth /etc/pam.d/${AUTH1}-auth.sss
  fi
done 


