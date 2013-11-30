{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell #-}

-- |
-- Module: Options.OptionTypes
-- License: MIT
module Options.OptionTypes where

import           Data.Int
import           Data.List (intercalate)
import qualified Data.Map as Map
import qualified Data.Set as Set
import qualified Data.Text as Text
import           Data.Word

import qualified Filesystem.Path as Path
import qualified Filesystem.Path.Rules as Path
import           Language.Haskell.TH

import           Options.Types

data Option a = Option
	{
	-- | Short flags are a single character. When entered by a user,
	-- they are preceded by a dash and possibly other short flags.
	--
	-- Short flags must be a letter or a number.
	--
	-- Example: An option with @optionShortFlags = [\'p\']@ may be set using:
	--
	-- >$ ./app -p 443
	-- >$ ./app -p443
	  optionShortFlags :: [Char]
	
	-- | Long flags are multiple characters. When entered by a user, they
	-- are preceded by two dashes.
	--
	-- Long flags may contain letters, numbers, @\'-\'@, and @\'_\'@.
	--
	-- Example: An option with @optionLongFlags = [\"port\"]@ may be set using:
	--
	-- >$ ./app --port 443
	-- >$ ./app --port=443
	, optionLongFlags :: [String]
	
	-- | Options may have a default value. This will be parsed as if the
	-- user had entered it on the command line.
	, optionDefault :: String
	
	-- | There are many types which an application or library might want
	-- to use when designing their options. By default, options are
	-- strings, but 'optionType' may be set to any supported type. See
	-- the \"Option types\" section for a list of supported types.
	, optionType :: OptionType a
	
	-- | An option's description is used with the default implementation
	-- of @--help@. It should be a short string describing what the option
	-- does.
	, optionDescription :: String
	
	-- | Which group the option is in. See the \"Option groups\" section
	-- for details.
	, optionGroup :: Group
	}

-- | An option's type determines how the option will be parsed, and which
-- Haskell type the parsed value will be stored as. There are many types
-- available, covering most basic types and a few more advanced types.
data OptionType val = OptionType
	{ optionTypeTemplateType :: Type
	, optionTypeUnary :: Bool
	, optionTypeParse :: String -> Either String val
	, optionTypeTemplateParse :: Q Exp
	}

-- | Store an option as a @'Bool'@. The option's value must be either
-- @\"true\"@ or @\"false\"@.
--
-- Boolean options are unary, which means that their value is optional when
-- specified on the command line. If a flag is present, the option is set to
-- True.
--
-- >$ ./app -q
-- >$ ./app --quiet
--
-- Boolean options may still be specified explicitly by using long flags with
-- the @--flag=value@ format. This is the only way to set a unary flag to
-- @\"false\"@.
--
-- >$ ./app --quiet=true
-- >$ ./app --quiet=false
optionTypeBool :: OptionType Bool
optionTypeBool = OptionType (ConT ''Bool) True parseBool [| parseBool |]

parseBool :: String -> Either String Bool
parseBool s = case s of
	"true" -> Right True
	"false" -> Right False
	-- TODO: include option flag
	_ -> Left (show s ++ " is not in {\"true\", \"false\"}.")

-- | Store an option value as a @'String'@. The value is decoded to Unicode
-- first, if needed. The value may contain non-Unicode bytes, in which case
-- they will be stored using GHC 7.4's encoding for mixed-use strings.
optionTypeString :: OptionType String
optionTypeString = OptionType (ConT ''String) False Right [| Right |]

-- | Store an option value as a @'Text.Text'@. The value is decoded to Unicode
-- first, if needed. If the value cannot be decoded, the stored value may have
-- the Unicode substitution character @'\65533'@ in place of some of the
-- original input.
optionTypeText :: OptionType Text.Text
optionTypeText = OptionType (ConT ''Text.Text) False parseText [| parseText |]

parseText :: String -> Either String Text.Text
parseText = Right . Text.pack

-- | Store an option value as a @'Path.FilePath'@.
optionTypeFilePath :: OptionType Path.FilePath
optionTypeFilePath = OptionType (ConT ''Path.FilePath) False parsePath [| parsePath |]

parsePath :: String -> Either String Path.FilePath
#if defined(CABAL_OS_WINDOWS)
parsePath s = Right (Path.decodeString Path.windows s)
#elif __GLASGOW_HASKELL__ == 702
parsePath s = Right (Path.decodeString Path.posix_ghc702 s)
#else
parsePath s = Right (Path.decodeString Path.posix_ghc704 s)
#endif

parseInteger :: String -> Either String Integer
parseInteger s = parsed where
	parsed = if valid
		then Right (read s)
		else Left (show s ++ " is not an integer.")
	valid = case s of
		[] -> False
		'-':s' -> allDigits s'
		_ -> allDigits s
	allDigits = all (\c -> c >= '0' && c <= '9')

parseBoundedIntegral :: (Bounded a, Integral a) => String -> String -> Either String a
parseBoundedIntegral label = parse where
	getBounds :: (Bounded a, Integral a) => (String -> Either String a) -> a -> a -> (Integer, Integer)
	getBounds _ min' max' = (toInteger min', toInteger max')
	
	(minInt, maxInt) = getBounds parse minBound maxBound
	
	parse s = case parseInteger s of
		Left err -> Left err
		Right int -> if int < minInt || int > maxInt
			then Left (show int ++ " is not within bounds [" ++ show minInt ++ ":" ++ show maxInt ++ "] of type " ++ label ++ ".")
			else Right (fromInteger int)

parseFloat :: Read a => String -> Either String a
parseFloat s = case reads s of
	[(x, "")] -> Right x
	_ -> Left (show s ++ " is not a number.")

-- | Store an option as an @'Int'@. The option value must be an integer /n/
-- such that @'minBound' <= n <= 'maxBound'@.
optionTypeInt :: OptionType Int
optionTypeInt = OptionType (ConT ''Int) False (parseBoundedIntegral "int") [| parseBoundedIntegral "int" |]

-- | Store an option as an @'Int8'@. The option value must be an integer /n/
-- such that @'minBound' <= n <= 'maxBound'@.
optionTypeInt8 :: OptionType Int8
optionTypeInt8 = OptionType (ConT ''Int8) False (parseBoundedIntegral "int8") [| parseBoundedIntegral "int8" |]

-- | Store an option as an @'Int16'@. The option value must be an integer /n/
-- such that @'minBound' <= n <= 'maxBound'@.
optionTypeInt16 :: OptionType Int16
optionTypeInt16 = OptionType (ConT ''Int16) False (parseBoundedIntegral "int16") [| parseBoundedIntegral "int16" |]

-- | Store an option as an @'Int32'@. The option value must be an integer /n/
-- such that @'minBound' <= n <= 'maxBound'@.
optionTypeInt32 :: OptionType Int32
optionTypeInt32 = OptionType (ConT ''Int32) False (parseBoundedIntegral "int32") [| parseBoundedIntegral "int32" |]

-- | Store an option as an @'Int64'@. The option value must be an integer /n/
-- such that @'minBound' <= n <= 'maxBound'@.
optionTypeInt64 :: OptionType Int64
optionTypeInt64 = OptionType (ConT ''Int64) False (parseBoundedIntegral "int64") [| parseBoundedIntegral "int64" |]

-- | Store an option as a @'Word'@. The option value must be a positive
-- integer /n/ such that @0 <= n <= 'maxBound'@.
optionTypeWord :: OptionType Word
optionTypeWord = OptionType (ConT ''Word) False (parseBoundedIntegral "word") [| parseBoundedIntegral "word" |]

-- | Store an option as a @'Word8'@. The option value must be a positive
-- integer /n/ such that @0 <= n <= 'maxBound'@.
optionTypeWord8 :: OptionType Word8
optionTypeWord8 = OptionType (ConT ''Word8) False (parseBoundedIntegral "word8") [| parseBoundedIntegral "word8" |]

-- | Store an option as a @'Word16'@. The option value must be a positive
-- integer /n/ such that @0 <= n <= 'maxBound'@.
optionTypeWord16 :: OptionType Word16
optionTypeWord16 = OptionType (ConT ''Word16) False (parseBoundedIntegral "word16") [| parseBoundedIntegral "word16" |]

-- | Store an option as a @'Word32'@. The option value must be a positive
-- integer /n/ such that @0 <= n <= 'maxBound'@.
optionTypeWord32 :: OptionType Word32
optionTypeWord32 = OptionType (ConT ''Word32) False (parseBoundedIntegral "word32") [| parseBoundedIntegral "word32" |]

-- | Store an option as a @'Word64'@. The option value must be a positive
-- integer /n/ such that @0 <= n <= 'maxBound'@.
optionTypeWord64 :: OptionType Word64
optionTypeWord64 = OptionType (ConT ''Word64) False (parseBoundedIntegral "word64") [| parseBoundedIntegral "word64" |]

-- | Store an option as an @'Integer'@. The option value must be an integer.
-- There is no minimum or maximum value.
optionTypeInteger :: OptionType Integer
optionTypeInteger = OptionType (ConT ''Integer) False parseInteger [| parseInteger |]

-- | Store an option as a @'Float'@. The option value must be a number. Due to
-- the imprecision of floating-point math, the stored value might not exactly
-- match the user's input. If the user's input is out of range for the
-- @'Float'@ type, it will be stored as @Infinity@ or @-Infinity@.
optionTypeFloat :: OptionType Float
optionTypeFloat = OptionType (ConT ''Float) False parseFloat [| parseFloat |]

-- | Store an option as a @'Double'@. The option value must be a number. Due to
-- the imprecision of floating-point math, the stored value might not exactly
-- match the user's input. If the user's input is out of range for the
-- @'Double'@ type, it will be stored as @Infinity@ or @-Infinity@.
optionTypeDouble :: OptionType Double
optionTypeDouble = OptionType (ConT ''Double) False parseFloat [| parseFloat |]

-- | Store an option as a @'Maybe'@ of another type. The value will be
-- @Nothing@ if the option was not provided or is an empty string.
--
-- @
--'option' \"optTimeout\" (\\o -> o
--    { 'optionLongFlags' = [\"timeout\"]
--    , 'optionType' = 'optionTypeMaybe' 'optionTypeInt'
--    })
-- @
optionTypeMaybe :: OptionType a -> OptionType (Maybe a)
optionTypeMaybe (OptionType valType unary valParse valParseExp) = OptionType (AppT (ConT ''Maybe) valType) unary
	(parseMaybe valParse)
	[| parseMaybe $valParseExp |]

parseMaybe :: (String -> Either String a) -> String -> Either String (Maybe a)
parseMaybe p s = case s of
	"" -> Right (Nothing)
	_ -> case p s of
		Left err -> Left err
		Right a -> Right (Just a)

$([d| |])

-- | Store an option as a @'Set.Set'@, using another option type for the
-- elements. The separator should be a character that will not occur within
-- the values, such as a comma or semicolon.
--
-- Duplicate elements in the input are permitted.
--
-- @
--'option' \"optNames\" (\\o -> o
--    { 'optionLongFlags' = [\"names\"]
--    , 'optionDefault' = \"Alice;Bob;Charles\"
--    , 'optionType' = 'optionTypeSet' \';\' 'optionTypeString'
--    })
-- @
optionTypeSet :: Ord a
              => Char -- ^ Element separator
              -> OptionType a -- ^ Element type
              -> OptionType (Set.Set a)
optionTypeSet sep (OptionType valType _ valParse valParseExp) = OptionType (AppT (ConT ''Set.Set) valType) False
	(\s -> parseSet valParse (split sep s))
	[| \s -> parseSet $valParseExp (split sep s) |]

-- | Store an option as a 'Map.Map', using other option types for the keys and
-- values.
--
-- The item separator is used to separate key/value pairs from eachother. It
-- should be a character that will not occur within either the keys or values.
--
-- The value separator is used to separate the key from the value. It should
-- be a character that will not occur within the keys. It may occur within the
-- values.
--
-- Duplicate keys in the input are permitted. The final value for each key is
-- stored.
--
-- @
--'option' \"optNames\" (\\o -> o
--    { 'optionLongFlags' = [\"names\"]
--    , 'optionDefault' = \"name=Alice;hometown=Bucharest\"
--    , 'optionType' = 'optionTypeMap' \';\' \'=\' 'optionTypeString' 'optionTypeString'
--    })
-- @
optionTypeMap :: Ord k
              => Char -- ^ Item separator
              -> Char -- ^ Key/Value separator
              -> OptionType k -- ^ Key type
              -> OptionType v -- ^ Value type
              -> OptionType (Map.Map k v)
optionTypeMap itemSep keySep (OptionType keyType _ keyParse keyParseExp) (OptionType valType _ valParse valParseExp) = OptionType (AppT (AppT (ConT ''Map.Map) keyType) valType) False
	(\s -> parseMap keySep keyParse valParse (split itemSep s))
	[| \s -> parseMap keySep $keyParseExp $valParseExp (split itemSep s) |]

parseList :: (String -> Either String a) -> [String] -> Either String [a]
parseList p = loop where
	loop [] = Right []
	loop (x:xs) = case p x of
		Left err -> Left err
		Right v -> case loop xs of
			Left err -> Left err
			Right vs -> Right (v:vs)

parseSet :: Ord a => (String -> Either String a) -> [String] -> Either String (Set.Set a)
parseSet p strs = case parseList p strs of
	Left err -> Left err
	Right xs -> Right (Set.fromList xs)

parseMap :: Ord k => Char -> (String -> Either String k) -> (String -> Either String v) -> [String] -> Either String (Map.Map k v)
parseMap keySep pKey pVal = parsed where
	parsed strs = case parseList pItem strs of
		Left err -> Left err
		Right xs -> Right (Map.fromList xs)
	pItem s = case break (== keySep) s of
		(sKey, valAndSep) -> case valAndSep of
			[] -> Left ("Map item " ++ show s ++ " has no value.")
			_ : sVal -> case pKey sKey of
				Left err -> Left err
				Right key -> case pVal sVal of
					Left err -> Left err
					Right val -> Right (key, val)

split :: Char -> String -> [String]
split _ [] = []
split sep s0 = loop s0 where
	loop s = let
		(chunk, rest) = break (== sep) s
		cont = chunk : loop (tail rest)
		in if null rest then [chunk] else cont

$([d| |])

-- | Store an option as a list, using another option type for the elements.
-- The separator should be a character that will not occur within the values,
-- such as a comma or semicolon.
--
-- @
--'option' \"optNames\" (\\o -> o
--    { 'optionLongFlags' = [\"names\"]
--    , 'optionDefault' = \"Alice;Bob;Charles\"
--    , 'optionType' = 'optionTypeList' \';\' 'optionTypeString'
--    })
-- @
optionTypeList :: Char -- ^ Element separator
               -> OptionType a -- ^ Element type
               -> OptionType [a]
optionTypeList sep (OptionType valType _ valParse valParseExp) = OptionType (AppT ListT valType) False
	(\s -> parseList valParse (split sep s))
	[| \s -> parseList $valParseExp (split sep s) |]

-- | Store an option as one of a set of enumerated values. The option
-- type must be defined in a separate file.
--
-- >-- MyApp/Types.hs
-- >data Mode = ModeFoo | ModeBar
-- >    deriving (Enum)
--
-- @
-- -- Main.hs
--import MyApp.Types
--
--'defineOptions' \"MainOptions\" $ do
--    'option' \"optMode\" (\\o -> o
--        { 'optionLongFlags' = [\"mode\"]
--        , 'optionDefault' = \"foo\"
--        , 'optionType' = 'optionTypeEnum' ''Mode
--            [ (\"foo\", ModeFoo)
--            , (\"bar\", ModeBar)
--            ]
--        })
-- @
--
-- >$ ./app
-- >Running in mode ModeFoo
-- >$ ./app --mode=bar
-- >Running in mode ModeBar
optionTypeEnum :: Enum a => Name -> [(String, a)] -> OptionType a
optionTypeEnum typeName values = do
	let intlist = [(k, fromEnum v) | (k, v) <- values]
	let setString = "{" ++ intercalate ", " [show k | (k, _) <- values] ++ "}."
	OptionType (ConT typeName) False
		(\s -> case lookup s values of
			Just v -> Right v
			Nothing -> Left (show s ++ " is not in " ++ setString))
		[| \s -> case lookup s intlist of
			Just v -> Right (toEnum v)
			-- TODO: include option flag and available values
			Nothing -> Left (show s ++ " is not in " ++ setString) |]
