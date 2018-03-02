# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initial setup for one-click-installer
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use base "y2logsstep";
use utils;
use testapi;

sub run {
    my $timeout = 120;
    if (get_var('BETA')) {
        assert_screen 'oci-betawarning', $timeout;
        send_key 'ret';
        $timeout = 30;
    }
    if (get_var('HDDSIZEGB') < 12) {
        assert_screen 'error-small-disk', $timeout;
        send_key 'ret';
        $timeout = 30;
    }
    assert_screen 'oci-overview', $timeout;
    mouse_hide;

    # Check release notes
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-e';
        assert_screen 'release-notes-' . get_var('VERSION');
        send_key 'ret';
    }
    else {
        assert_and_click 'release-notes-open';
        assert_screen 'release-notes-' . get_var('VERSION');
        assert_and_click 'release-notes-close';
    }

    # Check DUD - poo#17072
    assert_screen 'oci-caption-dud' if get_var('DUD');
}

1;
# vim: set sw=4 et:
