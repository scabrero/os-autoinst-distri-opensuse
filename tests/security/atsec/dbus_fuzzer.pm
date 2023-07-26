# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'DBus fuzzer' test case of ATSec test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#109978

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use atsec_test;
use Mojo::Util 'trim';
use Data::Dumper;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Install the required packages
    zypper_call('in glib2-devel libffi-devel');

    # Compile
    assert_script_run("cd $atsec_test::code_dir/pentest/dfuzzer-master/src");
    assert_script_run('make');

    my $output = script_output('./dfuzzer -l 2>&1');

    # Parse the output and push the items to related array
    my @bus_list;
    foreach my $line (split(/\n/, $output)) {
        $line = trim($line);
        if ($line =~ /SESSION\s+BUS|SYSTEM\s+BUS|Session bus not found/) {
            next;
        }
        elsif ($line =~ /Exit status:\s+(\d)/) {
            if ($1 != 0) {
                record_info('Fail to get system bus information', $output, result => 'fail');
                $self->result('fail');
            }
        } else {
            push(@bus_list, $line);
        }
    }

    record_info('Result of dfuzzer -l', Dumper(\@bus_list));

    # Analyse the results
    my %hash_white_list = map { $_ => 1 } @atsec_test::white_list_for_dbus;
    my @unknown_bus_name = grep { !$hash_white_list{$_} } (@bus_list);

    # After filtering there should be no unknown name
    if (scalar(@unknown_bus_name) > 0) {
        record_info('There are unknow bus name', Dumper(\@unknown_bus_name), result => 'fail');
        $self->result('fail');
    }

    # Create a directory to restore the log message generated by dfuzzer
    my $log_dir = 'logs';
    assert_script_run("mkdir $log_dir");

    # Test the Dbus
    my %test_result;
    foreach my $dbus (@bus_list) {
        my $log_file = "$log_dir/$dbus.log";

        # Don't test 'org.opensuse.Snapper' because it isn't in the test list
        next if ($dbus eq 'org.opensuse.Snapper');

        # Skip the DBus has been tested. Some DBus names are in 'session bus' and 'system bus'.
        next if $test_result{$dbus};

        $test_result{$dbus} = 'PASS';
        script_run("./dfuzzer -v -n $dbus > $log_file 2>&1", timeout => 420);

        # Upload log file generated by dfuzzer
        upload_logs($log_file);

        # Check the test result
        my $filter_output = script_output("grep -B 1 -i 'exit status' $log_file");

        my $exit_code = $filter_output =~ /Exit status:\s+(\d)/ ? $1 : 'unknow';

        # Test case pass
        next if ($exit_code == 0);

        # When exit code is 1, may be internal dfuzzer error, need to parse output details
        next if ($exit_code == 1 && $filter_output =~ /Unable to get introspection data/);

        # Test case fail
        $test_result{$dbus} = 'FAIL';
        record_info("Test $dbus fail", "Please see the log file $log_file for more details", result => 'fail');

        $self->result('fail');
    }
    record_info('Results of testing dbus', Dumper(\%test_result));
}

sub test_flags {
    return {always_rollback => 1, fatal => 0};
}

1;
