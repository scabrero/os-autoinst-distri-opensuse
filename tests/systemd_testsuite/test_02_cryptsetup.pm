# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-02-CRYPTSETUP from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base "consoletest";
use warnings;
use strict;
use testapi;
use utils 'zypper_call';
use power_action_utils 'power_action';

sub run {
    #prepare test
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run './run-tests.sh TEST-02-CRYPTSETUP --setup 2>&1 | tee /tmp/testsuite.log', 600;
    assert_script_run 'ls -l /etc/systemd/system/testsuite.service';
    wait_still_screen 30;
    #reboot
    power_action('reboot', textmode => 1);
    assert_screen('linux-login', 180);
    type_string "root\n";
    wait_still_screen 3;
    type_password;
    wait_still_screen 3;
    send_key 'ret';
    #run test
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run './run-tests.sh TEST-02-CRYPTSETUP --run 2>&1 | tee /tmp/testsuite.log', 60;
    assert_screen("systemd-testsuite-test-02-cryptsetup");
}

sub test_flags {
    return { always_rollback => 1 };
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    assert_script_run('tar -cjf TEST-02-CRYPTSETUP-logs.tar.bz2 /var/opt/systemd-tests/logs/');
    upload_logs('TEST-02-CRYPTSETUP-logs.tar.bz2');
}

1;
