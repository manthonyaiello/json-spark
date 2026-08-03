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

package Test_Parsers is

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
   --  Return the suite of test cases exercising JSON.Parsers
   --  @return The suite, owned by this package

private

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;
   --  The fixture the cases below run against; they need no state of
   --  their own

   --  Keyword
   procedure Test_True_Text (Object : in out Test);
   --  Parse text 'true'
   --  @param Object The fixture the case runs against
   procedure Test_False_Text (Object : in out Test);
   --  Parse text 'false'
   --  @param Object The fixture the case runs against
   procedure Test_Null_Text (Object : in out Test);
   --  Parse text 'null'
   --  @param Object The fixture the case runs against

   --  String
   procedure Test_Empty_String_Text (Object : in out Test);
   --  Parse text '""'
   --  @param Object The fixture the case runs against
   procedure Test_Non_Empty_String_Text (Object : in out Test);
   --  Parse text '"test"'
   --  @param Object The fixture the case runs against
   procedure Test_Number_String_Text (Object : in out Test);
   --  Parse text '"12.34"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Unicode_String_Text (Object : in out Test);
   --  Parse text '"\u0041"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Unicode_Control_String_Text (Object : in out Test);
   --  Parse text '"a\u001bb"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Unicode_Two_Byte_String_Text (Object : in out Test);
   --  Parse text '"\u00e9"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Unicode_Three_Byte_String_Text (Object : in out Test);
   --  Parse text '"\u20ac"'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Unicode_Surrogate_Pair_String_Text (Object : in out Test);
   --  Parse text '"\ud834\udd1e"'
   --  @param Object The fixture the case runs against

   --  Integer/float number
   procedure Test_Integer_Number_Text (Object : in out Test);
   --  Parse text '42'
   --  @param Object The fixture the case runs against
   procedure Test_Integer_Number_To_Float_Text (Object : in out Test);
   --  Parse text '42' as float
   --  @param Object The fixture the case runs against
   procedure Test_Float_Number_Text (Object : in out Test);
   --  Parse text '3.14'
   --  @param Object The fixture the case runs against

   --  Array
   procedure Test_Empty_Array_Text (Object : in out Test);
   --  Parse text '[]'
   --  @param Object The fixture the case runs against
   procedure Test_One_Element_Array_Text (Object : in out Test);
   --  Parse text '["test"]'
   --  @param Object The fixture the case runs against
   procedure Test_Multiple_Elements_Array_Text (Object : in out Test);
   --  Parse text '[3.14, true]'
   --  @param Object The fixture the case runs against
   procedure Test_Array_Iterable (Object : in out Test);
   --  Iterate over '[false, "test", 0.271e1]'
   --  @param Object The fixture the case runs against
   procedure Test_Multiple_Array_Iterable (Object : in out Test);
   --  Iterate over '{"foo":[1, "2"],"bar":[0.271e1]}'
   --  @param Object The fixture the case runs against

   --  Object
   procedure Test_Empty_Object_Text (Object : in out Test);
   --  Parse text '{}'
   --  @param Object The fixture the case runs against
   procedure Test_One_Member_Object_Text (Object : in out Test);
   --  Parse text '{"foo":"bar"}'
   --  @param Object The fixture the case runs against
   procedure Test_Multiple_Members_Object_Text (Object : in out Test);
   --  Parse text '{"foo":1,"bar":2}'
   --  @param Object The fixture the case runs against
   procedure Test_Object_Iterable (Object : in out Test);
   --  Iterate over '{"foo":1,"bar":2}'
   --  @param Object The fixture the case runs against

   procedure Test_Array_Object_Array (Object : in out Test);
   --  Parse text '[{"foo":[true, 42]}]'
   --  @param Object The fixture the case runs against
   procedure Test_Object_Array_Object (Object : in out Test);
   --  Parse text '{"foo":[null, {"bar": 42}]}'
   --  @param Object The fixture the case runs against

   procedure Test_Object_No_Array (Object : in out Test);
   --  Test getting array from text '{}'
   --  @param Object The fixture the case runs against
   procedure Test_Object_No_Object (Object : in out Test);
   --  Test getting object from text '{}'
   --  @param Object The fixture the case runs against

   --  Exceptions
   procedure Test_Empty_Text_Exception (Object : in out Test);
   --  Reject text ''
   --  @param Object The fixture the case runs against

   procedure Test_Array_No_Value_Separator_Exception (Object : in out Test);
   --  Reject text '[3.14"test"]'
   --  @param Object The fixture the case runs against
   procedure Test_Array_No_End_Array_Exception (Object : in out Test);
   --  Reject text '[true'
   --  @param Object The fixture the case runs against
   procedure Test_No_EOF_After_Array_Exception (Object : in out Test);
   --  Reject text '[1]2'
   --  @param Object The fixture the case runs against

   procedure Test_Object_No_Value_Separator_Exception (Object : in out Test);
   --  Reject text '{"foo":1"bar":2}'
   --  @param Object The fixture the case runs against
   procedure Test_Object_No_Name_Separator_Exception (Object : in out Test);
   --  Reject text '{"foo",true}'
   --  @param Object The fixture the case runs against
   procedure Test_Object_Key_No_String_Exception (Object : in out Test);
   --  Reject text '{42:true}'
   --  @param Object The fixture the case runs against
   procedure Test_Object_No_Second_Member_Exception (Object : in out Test);
   --  Reject text '{"foo":true,}'
   --  @param Object The fixture the case runs against
   procedure Test_Object_Duplicate_Keys_Exception (Object : in out Test);
   --  Reject text '{"foo":1,"foo":2}'
   --  @param Object The fixture the case runs against
   procedure Test_Object_No_Value_Exception (Object : in out Test);
   --  Reject text '{"foo":}'
   --  @param Object The fixture the case runs against
   procedure Test_Object_No_End_Object_Exception (Object : in out Test);
   --  Reject text '{"foo":true'
   --  @param Object The fixture the case runs against
   procedure Test_No_EOF_After_Object_Exception (Object : in out Test);
   --  Reject text '{"foo":true}[true]'
   --  @param Object The fixture the case runs against

end Test_Parsers;
