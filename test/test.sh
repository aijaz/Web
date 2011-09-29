#!/bin/bash
perl -MTest::Harness -e '$a=glob("*.pl");runtests($a)'
