#! /usr/bin/env perl
#
#   This file is part of the WebKit project
#
#   Copyright (C) 1999 Waldo Bastian (bastian@kde.org)
#   Copyright (C) 2007, 2012 Apple Inc. All rights reserved.
#   Copyright (C) 2008 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2010 Andras Becsi (abecsi@inf.u-szeged.hu), University of Szeged
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Library General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Library General Public License for more details.
#
#   You should have received a copy of the GNU Library General Public License
#   along with this library; see the file COPYING.LIB.  If not, write to
#   the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
use FindBin;
use lib "$FindBin::Bin/../bindings/scripts";

use Getopt::Long;
use preprocessor;
use strict;
use warnings;

my $defines;
my $preprocessor;
my $gperf;
GetOptions('defines=s' => \$defines,
           'preprocessor=s' => \$preprocessor,
           'gperf-executable=s' => \$gperf);

my @NAMES = applyPreprocessor("CSSValueKeywords.in", $defines, $preprocessor);

my %namesHash;
my @duplicates = ();

my @names = ();
my @lower_names = ();
my $numPredefinedProperties = 1;

foreach (@NAMES) {
  next if (m/(^\s*$)/);
  next if (/^#/);

  # Input may use a different EOL sequence than $/, so avoid chomp.
  $_ =~ s/[\r\n]+$//g;
  # CSS values need to be lower case.
  if (exists $namesHash{$_}) {
    push @duplicates, $_;
  } else {
    $namesHash{$_} = 1;
  }
  push @names, $_;
  push @lower_names, lc $_;
}

if (@duplicates > 0) {
    die 'Duplicate CSS value keywords  values: ', join(', ', @duplicates) . "\n";
}

open GPERF, ">CSSValueKeywords.gperf" || die "Could not open CSSValueKeywords.gperf for writing";
print GPERF << "EOF";
%{
/* This file is automatically generated from CSSValueKeywords.in by makevalues, do not edit */

#include \"config.h\"
#include \"CSSValueKeywords.h\"
#include \"HashTools.h\"
#include <wtf/ASCIICType.h>
#include <wtf/text/AtomString.h>
#include <wtf/text/WTFString.h>
#include <string.h>

IGNORE_WARNINGS_BEGIN(\"implicit-fallthrough\")

// Older versions of gperf like to use the `register` keyword.
#define register

namespace WebCore {
%}
%struct-type
struct Value;
%omit-struct-type
%language=C++
%readonly-tables
%compare-strncmp
%define class-name CSSValueKeywordsHash
%define lookup-function-name findValueImpl
%define hash-function-name value_hash_function
%define word-array-name value_word_list
%enum
%%
EOF

for my $i (0 .. $#names) {
  my $id = $names[$i];
  $id =~ s/(^[^-])|-(.)/uc($1||$2)/ge;
  print GPERF $lower_names[$i] . ", CSSValue" . $id . "\n";
}

print GPERF << "EOF";
%%
static const char* const valueList[] = {
    "",
EOF

foreach my $name (@names) {
  print GPERF "    \"" . $name . "\",\n";
}

print GPERF << "EOF";
    0
};

const Value* findValue(const char* str, unsigned int len)
{
    return CSSValueKeywordsHash::findValueImpl(str, len);
}

const char* getValueName(unsigned short id)
{
    if (id > lastCSSValueKeyword)
        return 0;
    return valueList[id];
}

const AtomString& getValueNameAtomString(CSSValueID id)
{
    if (id < firstCSSValueKeyword || id > lastCSSValueKeyword)
        return nullAtom();

    static AtomString* valueKeywordStrings = new AtomString[numCSSValueKeywords]; // Leaked intentionally.
    AtomString& valueKeywordString = valueKeywordStrings[id];
    if (valueKeywordString.isNull())
        valueKeywordString = getValueName(id);
    return valueKeywordString;
}

String getValueNameString(CSSValueID id)
{
    // We share the StringImpl with the AtomStrings.
    return getValueNameAtomString(id).string();
}

} // namespace WebCore

IGNORE_WARNINGS_END
EOF
close GPERF;


open HEADER, ">CSSValueKeywords.h" || die "Could not open CSSValueKeywords.h for writing";
print HEADER << "EOF";
/* This file is automatically generated from CSSValueKeywords.in by makevalues, do not edit */

#pragma once

#include <string.h>
#include <wtf/Forward.h>

namespace WebCore {

enum CSSValueID {
    CSSValueInvalid = 0,
EOF

my $first = 0; # Include CSSValueInvalid in the total number of values
my $i = $numPredefinedProperties;
my $maxLen = 0;
foreach my $name (@names) {
  my $id = $name;
  $id =~ s/(^[^-])|-(.)/uc($1||$2)/ge;
  print HEADER "    CSSValue" . $id . " = " . $i . ",\n";
  $i = $i + 1;
  if (length($name) > $maxLen) {
    $maxLen = length($name);
  }
}
my $num = $i - $first;
my $last = $i - 1;

print HEADER "};\n\n";
print HEADER "const int firstCSSValueKeyword = $first;\n";
print HEADER "const int numCSSValueKeywords = $num;\n";
print HEADER "const int lastCSSValueKeyword = $last;\n";
print HEADER "const size_t maxCSSValueKeywordLength = " . $maxLen . ";\n";
print HEADER << "EOF";

const char* getValueName(unsigned short id);
const WTF::AtomString& getValueNameAtomString(CSSValueID id);
WTF::String getValueNameString(CSSValueID id);

inline CSSValueID convertToCSSValueID(int value)
{
    ASSERT(value >= firstCSSValueKeyword && value <= lastCSSValueKeyword);
    return static_cast<CSSValueID>(value);
}

} // namespace WebCore
EOF
close HEADER;

if (not $gperf) {
    $gperf = $ENV{GPERF} ? $ENV{GPERF} : "gperf";
}
system("\"$gperf\" --key-positions=\"*\" -D -n -s 2 CSSValueKeywords.gperf --output-file=CSSValueKeywords.cpp") == 0 || die "calling gperf failed: $?";
