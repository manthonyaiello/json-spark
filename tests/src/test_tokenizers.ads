--  SPDX-License-Identifier: Apache-2.0
--
--  Copyright (c) 2016 onox <denkpadje@gmail.com>
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

with AUnit.Test_Suites;
with AUnit.Test_Fixtures;

package Test_Tokenizers is

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
   --  Return the suite of test cases exercising JSON.Tokenizers
   --  @return The suite, owned by this package

private

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;
   --  The fixture the cases below run against; they need no state of
   --  their own

   -----------------------------------------------------------------------------
   --                                 Keyword                                 --
   -----------------------------------------------------------------------------

   procedure Test_Null_Token (Object : in out Test);
   --  Tokenize text 'null'
   --  @param Object The fixture the case runs against
   procedure Test_True_Token (Object : in out Test);
   --  Tokenize text 'true'
   --  @param Object The fixture the case runs against
   procedure Test_False_Token (Object : in out Test);
   --  Tokenize text 'false'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                                  String                                 --
   -----------------------------------------------------------------------------

   procedure Test_Empty_String_Token (Object : in out Test);
   --  Tokenize text '""'
   --  @param Object The fixture the case runs against
   procedure Test_Non_Empty_String_Token (Object : in out Test);
   --  Tokenize text '"test"'
   --  @param Object The fixture the case runs against
   procedure Test_Number_String_Token (Object : in out Test);
   --  Tokenize text '"12.34"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Character_String_Token (Object : in out Test);
   --  Tokenize text '"horizontal\ttab"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Quotation_Solidus_String_Token (Object : in out Test);
   --  Tokenize text '"foo\"\\bar"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Unicode_String_Token (Object : in out Test);
   --  Tokenize text '"escaped\u001b"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Unicode_Uppercase_String_Token (Object : in out Test);
   --  Tokenize text '"\u00E9"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Unicode_Surrogate_Pair_String_Token (Object : in out Test);
   --  Tokenize text '"\ud834\udd1e"'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                           Integer/float number                          --
   -----------------------------------------------------------------------------

   procedure Test_Zero_Number_Token (Object : in out Test);
   --  Tokenize text '0'
   --  @param Object The fixture the case runs against
   procedure Test_Integer_Number_Token (Object : in out Test);
   --  Tokenize text '42'
   --  @param Object The fixture the case runs against
   procedure Test_Float_Number_Token (Object : in out Test);
   --  Tokenize text '3.14'
   --  @param Object The fixture the case runs against
   procedure Test_Negative_Float_Number_Token (Object : in out Test);
   --  Tokenize text '-2.71'
   --  @param Object The fixture the case runs against
   procedure Test_Integer_Exponent_Number_Token (Object : in out Test);
   --  Tokenize text '4e2'
   --  @param Object The fixture the case runs against
   procedure Test_Float_Exponent_Number_Token (Object : in out Test);
   --  Tokenize text '0.314e1'
   --  @param Object The fixture the case runs against
   procedure Test_Float_Negative_Exponent_Number_Token (Object : in out Test);
   --  Tokenize text '4e-1'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                                  Array                                  --
   -----------------------------------------------------------------------------

   procedure Test_Empty_Array_Tokens (Object : in out Test);
   --  Tokenize text '[]'
   --  @param Object The fixture the case runs against
   procedure Test_One_Element_Array_Tokens (Object : in out Test);
   --  Tokenize text '[null]'
   --  @param Object The fixture the case runs against
   procedure Test_Two_Elements_Array_Tokens (Object : in out Test);
   --  Tokenize text '[1,2]'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                                  Object                                 --
   -----------------------------------------------------------------------------

   procedure Test_Empty_Object_Tokens (Object : in out Test);
   --  Tokenize text '{}'
   --  @param Object The fixture the case runs against
   procedure Test_One_Pair_Object_Tokens (Object : in out Test);
   --  Tokenize text '{"foo":"bar"}'
   --  @param Object The fixture the case runs against
   procedure Test_Two_Pairs_Object_Tokens (Object : in out Test);
   --  Tokenize text '{"foo": true,"bar":false}'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                                Exceptions                               --
   -----------------------------------------------------------------------------

   procedure Test_Control_Character_String_Exception (Object : in out Test);
   --  Reject text '"no\nnewline"'
   --  @param Object The fixture the case runs against
   procedure Test_Unexpected_Escaped_Character_String_Exception (Object : in out Test);
   --  Reject text '"unexpected\xcharacter"'
   --  @param Object The fixture the case runs against
   procedure Test_Truncated_Escaped_Unicode_String_Exception (Object : in out Test);
   --  Reject text '"\u12"'
   --  @param Object The fixture the case runs against
   procedure Test_Non_Hex_Escaped_Unicode_String_Exception (Object : in out Test);
   --  Reject text '"\uzzzz"'
   --  @param Object The fixture the case runs against
   procedure Test_Lone_High_Surrogate_String_Exception (Object : in out Test);
   --  Reject text '"\ud834"'
   --  @param Object The fixture the case runs against
   procedure Test_Lone_Low_Surrogate_String_Exception (Object : in out Test);
   --  Reject text '"\udd1e"'
   --  @param Object The fixture the case runs against
   procedure Test_High_Surrogate_Without_Low_String_Exception (Object : in out Test);
   --  Reject text '"\ud834A"'
   --  @param Object The fixture the case runs against
   procedure Test_High_Surrogate_Wrong_Escape_String_Exception (Object : in out Test);
   --  Reject text '"\ud834\t"'
   --  @param Object The fixture the case runs against
   procedure Test_Minus_Number_EOF_Exception (Object : in out Test);
   --  Reject text '-'
   --  @param Object The fixture the case runs against
   procedure Test_Minus_Number_Exception (Object : in out Test);
   --  Reject text '-,'
   --  @param Object The fixture the case runs against
   procedure Test_End_Dot_Number_Exception (Object : in out Test);
   --  Reject text '3.'
   --  @param Object The fixture the case runs against
   procedure Test_End_Exponent_Number_Exception (Object : in out Test);
   --  Reject text '1E'
   --  @param Object The fixture the case runs against
   procedure Test_End_Dot_Exponent_Number_Exception (Object : in out Test);
   --  Reject text '1.E'
   --  @param Object The fixture the case runs against
   procedure Test_End_Exponent_Minus_Number_Exception (Object : in out Test);
   --  Reject text '1E-'
   --  @param Object The fixture the case runs against
   procedure Test_End_Exponent_One_Digit_Exception (Object : in out Test);
   --  Reject text '1E,'
   --  @param Object The fixture the case runs against
   procedure Test_End_Exponent_Minus_One_Digit_Exception (Object : in out Test);
   --  Reject text '1E-,'
   --  @param Object The fixture the case runs against
   procedure Test_Prefixed_Plus_Number_Exception (Object : in out Test);
   --  Reject text '+42'
   --  @param Object The fixture the case runs against
   procedure Test_Leading_Zeroes_Integer_Number_Exception (Object : in out Test);
   --  Reject text '-02'
   --  @param Object The fixture the case runs against
   procedure Test_Leading_Zeroes_Float_Number_Exception (Object : in out Test);
   --  Reject text '-003.14'
   --  @param Object The fixture the case runs against
   procedure Test_Incomplete_True_Text_Exception (Object : in out Test);
   --  Reject text 'tr'
   --  @param Object The fixture the case runs against
   procedure Test_Incomplete_False_Text_Exception (Object : in out Test);
   --  Reject text 'f'
   --  @param Object The fixture the case runs against
   procedure Test_Incomplete_Null_Text_Exception (Object : in out Test);
   --  Reject text 'nul'
   --  @param Object The fixture the case runs against
   procedure Test_Unknown_Keyword_Text_Exception (Object : in out Test);
   --  Reject text 'unexpected'
   --  @param Object The fixture the case runs against

end Test_Tokenizers;
