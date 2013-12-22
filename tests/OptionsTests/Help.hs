{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- Copyright (C) 2012 John Millikin <jmillikin@gmail.com>
--
-- See license.txt for details
module OptionsTests.Help
	( suite_Help
	) where

import qualified Data.Map as Map
import           Test.Chell

import           Options.Types
import           Options.Help

suite_Help :: Suite
suite_Help = suite "help"
	suite_AddHelpFlags
	test_CheckHelpFlag
	test_ShowHelpSummary
	test_ShowHelpSummary_Subcommand
	test_ShowHelpAll
	test_ShowHelpAll_Subcommand
	test_ShowHelpGroup
	test_ShowHelpGroup_Subcommand
	test_ShowHelpGroup_SubcommandInvalid

suite_AddHelpFlags :: Suite
suite_AddHelpFlags = suite "addHelpFlags"
	test_AddHelpFlags_None
	test_AddHelpFlags_Short
	test_AddHelpFlags_Long
	test_AddHelpFlags_Both
	test_AddHelpFlags_NoAll
	test_AddHelpFlags_Subcommand

groupHelp :: Maybe Group
groupHelp = Just (Group
	{ groupName = "all"
	, groupTitle = "Help Options"
	, groupDescription = "Show all help options."
	})

infoHelpSummary :: [Char] -> [String] -> OptionInfo
infoHelpSummary shorts longs = OptionInfo
	{ optionInfoKey = OptionKeyHelpSummary
	, optionInfoShortFlags = shorts
	, optionInfoLongFlags = longs
	, optionInfoDefault = "false"
	, optionInfoUnary = True
	, optionInfoDescription = "Show option summary." 
	, optionInfoGroup = groupHelp
	, optionInfoLocation = Nothing
	, optionInfoTypeName = "help"
	}

infoHelpAll :: OptionInfo
infoHelpAll = OptionInfo
	{ optionInfoKey = OptionKeyHelpGroup "all"
	, optionInfoShortFlags = []
	, optionInfoLongFlags = ["help-all"]
	, optionInfoDefault = "false"
	, optionInfoUnary = True
	, optionInfoDescription = "Show all help options." 
	, optionInfoGroup = groupHelp
	, optionInfoLocation = Nothing
	, optionInfoTypeName = "help"
	}

test_AddHelpFlags_None :: Test
test_AddHelpFlags_None = assertions "none" $ do
	let commandDefs = OptionDefinitions
		[ OptionInfo (OptionKey "test.help") ['h'] ["help"] "default" False "" Nothing Nothing ""
		]
		[]
	let helpAdded = addHelpFlags commandDefs
	let OptionDefinitions opts subcmds = helpAdded
	
	$expect (equal opts
		[ infoHelpAll
		, OptionInfo (OptionKey "test.help") ['h'] ["help"] "default" False "" Nothing Nothing ""
		])
	$expect (equal subcmds [])

test_AddHelpFlags_Short :: Test
test_AddHelpFlags_Short = assertions "short" $ do
	let commandDefs = OptionDefinitions
		[ OptionInfo (OptionKey "test.help") [] ["help"] "default" False "" Nothing Nothing ""
		]
		[]
	let helpAdded = addHelpFlags commandDefs
	let OptionDefinitions opts subcmds = helpAdded
	
	$expect (equal opts
		[ infoHelpSummary ['h'] []
		, infoHelpAll
		, OptionInfo (OptionKey "test.help") [] ["help"] "default" False "" Nothing Nothing ""
		])
	$expect (equal subcmds [])

test_AddHelpFlags_Long :: Test
test_AddHelpFlags_Long = assertions "long" $ do
	let commandDefs = OptionDefinitions
		[ OptionInfo (OptionKey "test.help") ['h'] [] "default" False "" Nothing Nothing ""
		]
		[]
	let helpAdded = addHelpFlags commandDefs
	let OptionDefinitions opts subcmds = helpAdded
	
	$expect (equal opts
		[ infoHelpSummary [] ["help"]
		, infoHelpAll
		, OptionInfo (OptionKey "test.help") ['h'] [] "default" False "" Nothing Nothing ""
		])
	$expect (equal subcmds [])

test_AddHelpFlags_Both :: Test
test_AddHelpFlags_Both = assertions "both" $ do
	let commandDefs = OptionDefinitions [] []
	let helpAdded = addHelpFlags commandDefs
	let OptionDefinitions opts subcmds = helpAdded
	
	$expect (equal opts
		[ infoHelpSummary ['h'] ["help"]
		, infoHelpAll
		])
	$expect (equal subcmds [])

test_AddHelpFlags_NoAll :: Test
test_AddHelpFlags_NoAll = assertions "no-all" $ do
	let commandDefs = OptionDefinitions
		[ OptionInfo (OptionKey "test.help") ['h'] ["help", "help-all"] "default" False "" Nothing Nothing ""
		]
		[]
	let helpAdded = addHelpFlags commandDefs
	let OptionDefinitions opts subcmds = helpAdded
	
	$expect (equal opts
		[ OptionInfo (OptionKey "test.help") ['h'] ["help", "help-all"] "default" False "" Nothing Nothing ""
		])
	$expect (equal subcmds [])

test_AddHelpFlags_Subcommand :: Test
test_AddHelpFlags_Subcommand = assertions "subcommand" $ do
	let cmd1_a = OptionInfo (OptionKey "test.cmd1.a") ['a'] [] "" False "" (Just Group
		{ groupName = "foo"
		, groupTitle = "Foo Options"
		, groupDescription = "More Foo Options"
		}) Nothing ""
	let cmd1_b = OptionInfo (OptionKey "test.cmd1.b") ['b'] [] "" False "" (Just Group
		{ groupName = "all"
		, groupTitle = "All Options"
		, groupDescription = "More All Options"
		}) Nothing ""
	let commandDefs = OptionDefinitions
		[]
		[("cmd1", [cmd1_a, cmd1_b])]
	let helpAdded = addHelpFlags commandDefs
	let OptionDefinitions opts subcmds = helpAdded
	
	let helpFoo = OptionInfo
		{ optionInfoKey = OptionKeyHelpGroup "foo"
		, optionInfoShortFlags = []
		, optionInfoLongFlags = ["help-foo"]
		, optionInfoDefault = "false"
		, optionInfoUnary = True
		, optionInfoDescription = "More Foo Options" 
		, optionInfoGroup = Just (Group
			{ groupName = "all"
			, groupTitle = "Help Options"
			, groupDescription = "Show all help options."
			})
		, optionInfoLocation = Nothing
		, optionInfoTypeName = "help"
		}
	
	$expect (equal opts
		[ infoHelpSummary ['h'] ["help"]
		, infoHelpAll
		])
	$expect (equal subcmds [("cmd1", [helpFoo, cmd1_a, cmd1_b])])

test_CheckHelpFlag :: Test
test_CheckHelpFlag = assertions "checkHelpFlag" $ do
	let checkFlag keys = equal (checkHelpFlag (Tokens (Map.fromList [(k, TokenUnary "-h") | k <- keys]) []))
	
	$expect (checkFlag [] Nothing)
	$expect (checkFlag [OptionKeyHelpSummary] (Just HelpSummary))
	$expect (checkFlag [OptionKeyHelpGroup "all"] (Just HelpAll))
	$expect (checkFlag [OptionKeyHelpGroup "foo"] (Just (HelpGroup "foo")))

variedOptions :: OptionDefinitions
variedOptions = addHelpFlags $ OptionDefinitions
	[ OptionInfo (OptionKey "test.a") ['a'] ["long-a"] "def" False "a description here" Nothing Nothing ""
	, OptionInfo (OptionKey "test.long1") [] ["a-looooooooooooong-option"] "def" False "description here" Nothing Nothing ""
	, OptionInfo (OptionKey "test.long2") [] ["a-loooooooooooooong-option"] "def" False "description here" Nothing Nothing ""
	, OptionInfo (OptionKey "test.b") ['b'] ["long-b"] "def" False "b description here" Nothing Nothing ""
	, OptionInfo (OptionKey "test.g") ['g'] ["long-g"] "def" False "g description here" (Just Group 
		{ groupName = "group"
		, groupTitle = "Grouped options"
		, groupDescription = "Show grouped options."
		}) Nothing ""
	]
	[ ("cmd1",
		[ OptionInfo (OptionKey "test.cmd1.z") ['z'] ["long-z"] "def" False "z description here" Nothing Nothing ""
		])
	, ("cmd2",
		[ OptionInfo (OptionKey "test.cmd2.y") ['y'] ["long-y"] "def" False "y description here" Nothing Nothing ""
		, OptionInfo (OptionKey "test.cmd2.g2") [] ["long-g2"] "def" False "g2 description here" (Just Group
			{ groupName = "group"
			, groupTitle = "Grouped options"
			, groupDescription = "Show grouped options."
			}) Nothing ""
		])
	]

test_ShowHelpSummary :: Test
test_ShowHelpSummary = assertions "showHelpSummary" $ do
	let expected = "\
	\Help Options:\n\
	\  -h, --help                  Show option summary.\n\
	\  --help-all                  Show all help options.\n\
	\  --help-group                Show grouped options.\n\
	\\n\
	\Application Options:\n\
	\  -a, --long-a                a description here\n\
	\  --a-looooooooooooong-option description here\n\
	\  --a-loooooooooooooong-option\n\
	\    description here\n\
	\  -b, --long-b                b description here\n\
	\\n\
	\Subcommands:\n\
	\  cmd1\n\
	\  cmd2\n\
	\\n"
	$expect (equalLines expected (helpFor HelpSummary variedOptions Nothing))

test_ShowHelpSummary_Subcommand :: Test
test_ShowHelpSummary_Subcommand = assertions "showHelpSummary-subcommand" $ do
	let expected = "\
	\Help Options:\n\
	\  -h, --help                  Show option summary.\n\
	\  --help-all                  Show all help options.\n\
	\  --help-group                Show grouped options.\n\
	\\n\
	\Application Options:\n\
	\  -a, --long-a                a description here\n\
	\  --a-looooooooooooong-option description here\n\
	\  --a-loooooooooooooong-option\n\
	\    description here\n\
	\  -b, --long-b                b description here\n\
	\\n\
	\Options for subcommand \"cmd1\":\n\
	\  -z, --long-z                z description here\n\
	\\n"
	$expect (equalLines expected (helpFor HelpSummary variedOptions (Just "cmd1")))

test_ShowHelpAll :: Test
test_ShowHelpAll = assertions "showHelpAll" $ do
	let expected = "\
	\Help Options:\n\
	\  -h, --help                  Show option summary.\n\
	\  --help-all                  Show all help options.\n\
	\  --help-group                Show grouped options.\n\
	\\n\
	\Grouped options:\n\
	\  -g, --long-g                g description here\n\
	\\n\
	\Application Options:\n\
	\  -a, --long-a                a description here\n\
	\  --a-looooooooooooong-option description here\n\
	\  --a-loooooooooooooong-option\n\
	\    description here\n\
	\  -b, --long-b                b description here\n\
	\\n\
	\Options for subcommand \"cmd1\":\n\
	\  -z, --long-z                z description here\n\
	\\n\
	\Options for subcommand \"cmd2\":\n\
	\  -y, --long-y                y description here\n\
	\  --long-g2                   g2 description here\n\
	\\n"
	$expect (equalLines expected (helpFor HelpAll variedOptions Nothing))

test_ShowHelpAll_Subcommand :: Test
test_ShowHelpAll_Subcommand = assertions "showHelpAll-subcommand" $ do
	let expected = "\
	\Help Options:\n\
	\  -h, --help                  Show option summary.\n\
	\  --help-all                  Show all help options.\n\
	\  --help-group                Show grouped options.\n\
	\\n\
	\Grouped options:\n\
	\  -g, --long-g                g description here\n\
	\\n\
	\Application Options:\n\
	\  -a, --long-a                a description here\n\
	\  --a-looooooooooooong-option description here\n\
	\  --a-loooooooooooooong-option\n\
	\    description here\n\
	\  -b, --long-b                b description here\n\
	\\n\
	\Options for subcommand \"cmd1\":\n\
	\  -z, --long-z                z description here\n\
	\\n"
	$expect (equalLines expected (helpFor HelpAll variedOptions (Just "cmd1")))

test_ShowHelpGroup :: Test
test_ShowHelpGroup = assertions "showHelpGroup" $ do
	let expected = "\
	\Grouped options:\n\
	\  -g, --long-g                g description here\n\
	\\n"
	$expect (equalLines expected (helpFor (HelpGroup "group") variedOptions Nothing))

test_ShowHelpGroup_Subcommand :: Test
test_ShowHelpGroup_Subcommand = assertions "showHelpGroup-subcommand" $ do
	let expected = "\
	\Grouped options:\n\
	\  -g, --long-g                g description here\n\
	\  --long-g2                   g2 description here\n\
	\\n"
	$expect (equalLines expected (helpFor (HelpGroup "group") variedOptions (Just "cmd2")))

test_ShowHelpGroup_SubcommandInvalid :: Test
test_ShowHelpGroup_SubcommandInvalid = assertions "showHelpGroup-subcommand-invalid" $ do
	let expected = "\
	\Grouped options:\n\
	\  -g, --long-g                g description here\n\
	\\n"
	$expect (equalLines expected (helpFor (HelpGroup "group") variedOptions (Just "noexist")))
