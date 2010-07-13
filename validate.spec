Name: validate
Version: 2.1	
Release: 1%{?dist}
Summary: Validates a cloud providers image of Red Hat Enterprise Linux	

Group: Development/Libraries
License: GPL
URL: http://github.com/weshayutin/valid	
Source0: %{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}
BuildArch:  noarch

# BuildRequires:	
# Requires:	

%description
A shell script that will run tests to validate that the image of Red Hat Enterprise Linux meets or exceeds the minimum requirements as defined by Red Hat. 


%prep
%setup -q


%build


%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/local
cp  $RPM_BUILD_DIR/%{name}-%{version}/image_validation.sh $RPM_BUILD_ROOT/usr/local/
cp  $RPM_BUILD_DIR/%{name}-%{version}/packages $RPM_BUILD_ROOT/usr/local/
cp  $RPM_BUILD_DIR/%{name}-%{version}/README $RPM_BUILD_ROOT/usr/local/
cp  $RPM_BUILD_DIR/%{name}-%{version}/rpmVerifyTable $RPM_BUILD_ROOT/usr/local/
cp  $RPM_BUILD_DIR/%{name}-%{version}/testlib.sh $RPM_BUILD_ROOT/usr/local/

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%config %{_sysconfdir}/image_validation.sh
%config %{_sysconfdir}/packages
%config %{_sysconfdir}/README
%config %{_sysconfdir}/rpmVerifyTable
%config %{_sysconfdir}/testlib.sh


%changelog
* Tue Jul 13 2010 Wes Hayutin 2.1-1
- initial build (whayutin@redhat.com)



