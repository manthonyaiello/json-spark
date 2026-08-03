--  SPDX-License-Identifier: Apache-2.0
--
--  Copyright (c) 2018 RREE <rolf.ebert.gcc@gmx.de>
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

package Test_Images is

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
   --  Return the suite of test cases exercising the JSON text produced by Types.Image
   --  @return The suite, owned by this package

private

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;
   --  The fixture the cases below run against; they need no state of
   --  their own

   -----------------------------------------------------------------------------
   --                                 Keyword                                 --
   -----------------------------------------------------------------------------

   procedure Test_True_Text (Object : in out Test);
   --  Image 'true'
   --  @param Object The fixture the case runs against
   procedure Test_False_Text (Object : in out Test);
   --  Image 'false'
   --  @param Object The fixture the case runs against
   procedure Test_Null_Text (Object : in out Test);
   --  Image 'null'
   --  @param Object The fixture the case runs against
   procedure Test_Escaped_Text (Object : in out Test);
   --  Image '"BS CR LF \ / HT"'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                                  String                                 --
   -----------------------------------------------------------------------------

   procedure Test_Empty_String_Text (Object : in out Test);
   --  Image '""'
   --  @param Object The fixture the case runs against
   procedure Test_Non_Empty_String_Text (Object : in out Test);
   --  Image '"test"'
   --  @param Object The fixture the case runs against
   procedure Test_Number_String_Text (Object : in out Test);
   --  Image '"12.34"'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                              Integer number                             --
   -----------------------------------------------------------------------------

   procedure Test_Integer_Number_Text (Object : in out Test);
   --  Image '42'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                                  Array                                  --
   -----------------------------------------------------------------------------

   procedure Test_Empty_Array_Text (Object : in out Test);
   --  Image '[]'
   --  @param Object The fixture the case runs against
   procedure Test_One_Element_Array_Text (Object : in out Test);
   --  Image '["test"]'
   --  @param Object The fixture the case runs against
   procedure Test_Multiple_Elements_Array_Text (Object : in out Test);
   --  Image '[3.14, true]'
   --  @param Object The fixture the case runs against

   -----------------------------------------------------------------------------
   --                                  Object                                 --
   -----------------------------------------------------------------------------

   procedure Test_Empty_Object_Text (Object : in out Test);
   --  Image '{}'
   --  @param Object The fixture the case runs against
   procedure Test_One_Member_Object_Text (Object : in out Test);
   --  Image '{"foo":"bar"}'
   --  @param Object The fixture the case runs against
   procedure Test_Multiple_Members_Object_Text (Object : in out Test);
   --  Image '{"foo":1,"bar":2}'
   --  @param Object The fixture the case runs against

   procedure Test_Array_Object_Array (Object : in out Test);
   --  Image '[{"foo":[true, 42]}]'
   --  @param Object The fixture the case runs against
   procedure Test_Object_Array_Object (Object : in out Test);
   --  Image '{"foo":[null, {"bar": 42}]}'
   --  @param Object The fixture the case runs against

end Test_Images;
