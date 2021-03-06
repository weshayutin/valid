Name: validate
Version: 6.1
Release: 1
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
mkdir -p $RPM_BUILD_ROOT/usr/local/valid
cp  $RPM_BUILD_DIR/%{name}-%{version}/image_validation.sh $RPM_BUILD_ROOT/usr/local/valid
cp  $RPM_BUILD_DIR/%{name}-%{version}/packages $RPM_BUILD_ROOT/usr/local/valid
cp  $RPM_BUILD_DIR/%{name}-%{version}/README $RPM_BUILD_ROOT/usr/local/valid
cp  $RPM_BUILD_DIR/%{name}-%{version}/rpmVerifyTable $RPM_BUILD_ROOT/usr/local/valid
cp  $RPM_BUILD_DIR/%{name}-%{version}/testlib.sh $RPM_BUILD_ROOT/usr/local/valid

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%config /usr/local/valid/image_validation.sh
%config /usr/local/valid/packages
%config /usr/local/valid/README
%config /usr/local/valid/rpmVerifyTable
%config /usr/local/valid/testlib.sh


%changelog
* Fri Jul 30 2010 wes hayutin <whayutin@redhat.com> 6.1-1
- changed bugzilla summary (whayutin@redhat.com)
- fixed a few bugs (whayutin@redhat.com)
- generalized disk and swap tests (whayutin@redhat.com)

* Tue Jul 13 2010 Wes Hayutin 5.1-1
- initial build (whayutin@redhat.com)



