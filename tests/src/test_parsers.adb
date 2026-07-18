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

with AUnit.Assertions;
with AUnit.Test_Caller;

with JSON.Parsers;
with JSON.Types;

package body Test_Parsers is

   package Types is new JSON.Types (Long_Integer, Long_Float);
   package Parsers is new JSON.Parsers (Types, Check_Duplicate_Keys => True);

   use AUnit.Assertions;

   package Caller is new AUnit.Test_Caller (Test);

   Test_Suite : aliased AUnit.Test_Suites.Test_Suite;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Name : constant String := "(Parsers) ";
   begin
      Test_Suite.Add_Test (Caller.Create (Name & "Parse text 'true'", Test_True_Text'Access));
      Test_Suite.Add_Test (Caller.Create (Name & "Parse text 'false'", Test_False_Text'Access));
      Test_Suite.Add_Test (Caller.Create (Name & "Parse text 'null'", Test_Null_Text'Access));

      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '""""'", Test_Empty_String_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '""test""'", Test_Non_Empty_String_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '""12.34""'", Test_Number_String_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '""\u0041""'",
         Test_Escaped_Unicode_String_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '""a\u001bb""'",
         Test_Escaped_Unicode_Control_String_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '""\u00e9""'",
         Test_Escaped_Unicode_Two_Byte_String_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '""\u20ac""'",
         Test_Escaped_Unicode_Three_Byte_String_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '""\ud834\udd1e""'",
         Test_Escaped_Unicode_Surrogate_Pair_String_Text'Access));

      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '42'", Test_Integer_Number_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '42' as float", Test_Integer_Number_To_Float_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '3.14'", Test_Float_Number_Text'Access));

      Test_Suite.Add_Test (Caller.Create (Name & "Parse text '[]'", Test_Empty_Array_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '[""test""]'", Test_One_Element_Array_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '[3.14, true]'", Test_Multiple_Elements_Array_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Iterate over '[false, ""test"", 0.271e1]'", Test_Array_Iterable'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Iterate over '{""foo"":[1, ""2""],""bar"":[0.271e1]}'",
         Test_Multiple_Array_Iterable'Access));

      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '{}'", Test_Empty_Object_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '{""foo"":""bar""}'", Test_One_Member_Object_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '{""foo"":1,""bar"":2}'", Test_Multiple_Members_Object_Text'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Iterate over '{""foo"":1,""bar"":2}'", Test_Object_Iterable'Access));

      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '[{""foo"":[true, 42]}]'", Test_Array_Object_Array'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Parse text '{""foo"":[null, {""bar"": 42}]}'", Test_Object_Array_Object'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Test getting array from text '{}'", Test_Object_No_Array'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Test getting object from text '{}'", Test_Object_No_Object'Access));

      --  Exceptions
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '[3.14""test""]'", Test_Array_No_Value_Separator_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '[true'", Test_Array_No_End_Array_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '[1]2'", Test_No_EOF_After_Array_Exception'Access));

      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text ''", Test_Empty_Text_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '{""foo"":1""bar"":2}'",
         Test_Object_No_Value_Separator_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '{""foo"",true}'", Test_Object_No_Name_Separator_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '{42:true}'", Test_Object_Key_No_String_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '{""foo"":true,}'", Test_Object_No_Second_Member_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '{""foo"":1,""foo"":2}'",
         Test_Object_Duplicate_Keys_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '{""foo"":}'", Test_Object_No_Value_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '{""foo"":true'", Test_Object_No_End_Object_Exception'Access));
      Test_Suite.Add_Test (Caller.Create
        (Name & "Reject text '{""foo"":true}[true]'", Test_No_EOF_After_Object_Exception'Access));

      return Test_Suite'Access;
   end Suite;

   use Types;

   procedure Fail (Message : String) is
   begin
      Assert (False, Message);
   end Fail;

   procedure Test_True_Text (Object : in out Test) is
      Text : constant String := "true";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Boolean_Kind, "Not a boolean");
      Assert (Value (Document), "Expected boolean value to be True");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_True_Text;

   procedure Test_False_Text (Object : in out Test) is
      Text : constant String := "false";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Boolean_Kind, "Not a boolean");
      Assert (not Value (Document), "Expected boolean value to be False");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_False_Text;

   procedure Test_Null_Text (Object : in out Test) is
      Text : constant String := "null";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Null_Kind, "Not a null");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Null_Text;

   procedure Test_Empty_String_Text (Object : in out Test) is
      Text : constant String := """""";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = String_Kind, "Not a string");
      Assert (Value (Document) = "", "String value not empty");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Empty_String_Text;

   procedure Test_Non_Empty_String_Text (Object : in out Test) is
      Text : constant String := """test""";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = String_Kind, "Not a string");
      Assert (Value (Document) = "test", "String value not equal to 'test'");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Non_Empty_String_Text;

   procedure Test_Number_String_Text (Object : in out Test) is
      Text : constant String := """12.34""";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = String_Kind, "Not a string");
      Assert (Value (Document) = "12.34", "String value not equal to 12.34''");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Number_String_Text;

   procedure Test_Escaped_Unicode_String_Text (Object : in out Test) is
      Text : constant String := """\u0041""";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = String_Kind, "Not a string");
      Assert (Value (Document) = "A", "String value not equal to 'A'");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Escaped_Unicode_String_Text;

   procedure Test_Escaped_Unicode_Control_String_Text (Object : in out Test) is
      Text : constant String := """a\u001bb""";

      Expected : constant String := 'a' & Character'Val (16#1B#) & 'b';

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = String_Kind, "Not a string");
      Assert (Value (Document) = Expected,
              "String value not 'a' & ESC & 'b'");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Escaped_Unicode_Control_String_Text;

   procedure Test_Escaped_Unicode_Two_Byte_String_Text (Object : in out Test) is
      Text : constant String := """\u00e9""";

      --  U+00E9 encoded as UTF-8
      Expected : constant String :=
        Character'Val (16#C3#) & Character'Val (16#A9#);

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = String_Kind, "Not a string");
      Assert (Value (Document) = Expected,
              "String value not UTF-8 encoding of U+00E9");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Escaped_Unicode_Two_Byte_String_Text;

   procedure Test_Escaped_Unicode_Three_Byte_String_Text (Object : in out Test) is
      Text : constant String := """\u20ac""";

      --  U+20AC encoded as UTF-8
      Expected : constant String :=
        Character'Val (16#E2#) & Character'Val (16#82#) & Character'Val (16#AC#);

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = String_Kind, "Not a string");
      Assert (Value (Document) = Expected,
              "String value not UTF-8 encoding of U+20AC");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Escaped_Unicode_Three_Byte_String_Text;

   procedure Test_Escaped_Unicode_Surrogate_Pair_String_Text (Object : in out Test) is
      Text : constant String := """\ud834\udd1e""";

      --  U+1D11E (musical symbol G clef) encoded as UTF-8
      Expected : constant String :=
        Character'Val (16#F0#) & Character'Val (16#9D#)
          & Character'Val (16#84#) & Character'Val (16#9E#);

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = String_Kind, "Not a string");
      Assert (Value (Document) = Expected,
              "String value not UTF-8 encoding of U+1D11E");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Escaped_Unicode_Surrogate_Pair_String_Text;

   procedure Test_Integer_Number_Text (Object : in out Test) is
      Text : constant String := "42";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Integer_Kind, "Not an integer");
      Assert (Value (Document) = 42, "Integer value not equal to 42");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Integer_Number_Text;

   procedure Test_Integer_Number_To_Float_Text (Object : in out Test) is
      Text : constant String := "42";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Integer_Kind, "Not an integer");
      Assert (Value (Document) = 42.0, "Integer value not equal to 42.0");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Integer_Number_To_Float_Text;

   procedure Test_Float_Number_Text (Object : in out Test) is
      Text : constant String := "3.14";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Float_Kind, "Not a float");
      Assert (Value (Document) = 3.14, "Float value not equal to 3.14");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Float_Number_Text;

   procedure Test_Empty_Array_Text (Object : in out Test) is
      Text : constant String := "[]";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Array_Kind, "Not an array");
      Assert (Length (Document) = 0, "Expected array to be empty");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Empty_Array_Text;

   procedure Test_One_Element_Array_Text (Object : in out Test) is
      Text : constant String := "[""test""]";
      String_Value_Message : constant String := "Expected string at index 1 to be equal to 'test'";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Array_Kind, "Not an array");
      Assert (Length (Document) = 1,
        "Expected length of array to be 1, got " & Length (Document)'Image);

      declare
         Element : constant access constant JSON_Value := Get (Document, 1);
      begin
         Assert (Element /= null, "Could not get value at index 1");
         Assert (Kind (Element) = String_Kind, "Not a string");
         Assert (Value (Element) = "test", String_Value_Message);
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_One_Element_Array_Text;

   procedure Test_Multiple_Elements_Array_Text (Object : in out Test) is
      Text : constant String := "[3.14, true]";
      Float_Value_Message   : constant String := "Expected float at index 1 to be equal to 3.14";
      Boolean_Value_Message : constant String := "Expected boolean at index 2 to be True";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Array_Kind, "Not an array");
      Assert (Length (Document) = 2, "Expected length of array to be 2");

      declare
         Element : constant access constant JSON_Value := Get (Document, 1);
      begin
         Assert (Element /= null, "Could not get value at index 1");
         Assert (Kind (Element) = Float_Kind, "Not a float");
         Assert (Value (Element) = 3.14, Float_Value_Message);
      end;
      declare
         Element : constant access constant JSON_Value := Get (Document, 2);
      begin
         Assert (Element /= null, "Could not get value at index 2");
         Assert (Kind (Element) = Boolean_Kind, "Not a boolean");
         Assert (Value (Element), Boolean_Value_Message);
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Multiple_Elements_Array_Text;

   procedure Test_Array_Iterable (Object : in out Test) is
      Text : constant String := "[false, ""test"", 0.271e1]";
      Iterations_Message : constant String := "Unexpected number of iterations";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Array_Kind, "Not an array");
      Assert (Length (Document) = 3, "Expected length of array to be 3");

      declare
         Element    : access constant JSON_Value := First (Document);
         Iterations : Natural := 0;
      begin
         while Element /= null loop
            Iterations := Iterations + 1;
            if Iterations = 1 then
               Assert (Kind (Element) = Boolean_Kind, "Not a boolean");
               Assert (not Value (Element), "Expected boolean value to be False");
            elsif Iterations = 2 then
               Assert (Kind (Element) = String_Kind, "Not a string");
               Assert (Value (Element) = "test", "Expected string value to be 'test'");
            elsif Iterations = 3 then
               Assert (Kind (Element) = Float_Kind, "Not a float");
               Assert (Value (Element) = 2.71, "Expected float value to be 2.71");
            end if;
            Element := Next (Element);
         end loop;
         Assert (Iterations = Length (Document), Iterations_Message);
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Array_Iterable;

   procedure Test_Multiple_Array_Iterable (Object : in out Test) is
      Text : constant String := "{""foo"":[1, ""2""],""bar"":[0.271e1]}";
      Iterations_Message : constant String := "Unexpected number of iterations";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Object_Kind, "Not an object");
      Assert (Length (Document) = 2, "Expected length of object to be 2");

      declare
         Foo : constant access constant JSON_Value := Get (Document, "foo");
      begin
         Assert (Foo /= null, "Could not get value of 'foo'");
         Assert (Kind (Foo) = Array_Kind, "Value of 'foo' not an array");

         declare
            Element    : access constant JSON_Value := First (Foo);
            Iterations : Natural := 0;
         begin
            while Element /= null loop
               Iterations := Iterations + 1;
               if Iterations = 1 then
                  Assert (Kind (Element) = Integer_Kind, "Not an integer");
                  Assert (Value (Element) = 1, "Expected integer value to be 1");
               elsif Iterations = 2 then
                  Assert (Kind (Element) = String_Kind, "Not a string");
                  Assert (Value (Element) = "2", "Expected string value to be '2'");
               end if;
               Element := Next (Element);
            end loop;
            Assert (Iterations = Length (Foo), Iterations_Message);
         end;
      end;

      declare
         Bar : constant access constant JSON_Value := Get (Document, "bar");
      begin
         Assert (Bar /= null, "Could not get value of 'bar'");
         Assert (Kind (Bar) = Array_Kind, "Value of 'bar' not an array");

         declare
            Element    : access constant JSON_Value := First (Bar);
            Iterations : Natural := 0;
         begin
            while Element /= null loop
               Iterations := Iterations + 1;
               if Iterations = 1 then
                  Assert (Kind (Element) = Float_Kind, "Not a float");
                  Assert (Value (Element) = 2.71, "Expected float value to be 2.71");
               end if;
               Element := Next (Element);
            end loop;
            Assert (Iterations = Length (Bar), Iterations_Message);
         end;
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Multiple_Array_Iterable;

   procedure Test_Empty_Object_Text (Object : in out Test) is
      Text : constant String := "{}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Object_Kind, "Not an object");
      Assert (Length (Document) = 0, "Expected object to be empty");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Empty_Object_Text;

   procedure Test_One_Member_Object_Text (Object : in out Test) is
      Text : constant String := "{""foo"":""bar""}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Object_Kind, "Not an object");
      Assert (Length (Document) = 1, "Expected length of object to be 1");

      declare
         Foo : constant access constant JSON_Value := Get (Document, "foo");
      begin
         Assert (Foo /= null, "Could not get value of 'foo'");
         Assert (Kind (Foo) = String_Kind, "Value of 'foo' not a string");
         Assert (Value (Foo) = "bar", "Expected string value of 'foo' to be 'bar'");
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_One_Member_Object_Text;

   procedure Test_Multiple_Members_Object_Text (Object : in out Test) is
      Text : constant String := "{""foo"":1,""bar"":2}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Object_Kind, "Not an object");
      Assert (Length (Document) = 2, "Expected length of object to be 2");

      declare
         Foo : constant access constant JSON_Value := Get (Document, "foo");
         Bar : constant access constant JSON_Value := Get (Document, "bar");
      begin
         Assert (Foo /= null, "Could not get value of 'foo'");
         Assert (Kind (Foo) = Integer_Kind, "Value of 'foo' not an integer");
         Assert (Value (Foo) = 1, "Expected integer value of 'foo' to be 1");

         Assert (Bar /= null, "Could not get value of 'bar'");
         Assert (Kind (Bar) = Integer_Kind, "Value of 'bar' not an integer");
         Assert (Value (Bar) = 2, "Expected integer value of 'bar' to be 2");
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Multiple_Members_Object_Text;

   procedure Test_Object_Iterable (Object : in out Test) is
      Text : constant String := "{""foo"":1,""bar"":2}";
      Iterations_Message : constant String := "Unexpected number of iterations";
      All_Keys_Message   : constant String := "Did not iterate over all expected keys";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Object_Kind, "Not an object");
      Assert (Length (Document) = 2, "Expected length of object to be 2");

      declare
         Element       : access constant JSON_Value := First (Document);
         Iterations    : Natural := 0;
         Retrieved_Foo : Boolean := False;
         Retrieved_Bar : Boolean := False;
      begin
         while Element /= null loop
            Iterations := Iterations + 1;
            if Iterations in 1 .. 2 then
               Assert (Key (Element) in "foo" | "bar",
                 "Expected key to be equal to 'foo' or 'bar'");

               Retrieved_Foo := Retrieved_Foo or Key (Element) = "foo";
               Retrieved_Bar := Retrieved_Bar or Key (Element) = "bar";
            end if;
            Element := Next (Element);
         end loop;
         Assert (Iterations = Length (Document), Iterations_Message);
         Assert (Retrieved_Foo and Retrieved_Bar, All_Keys_Message);
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Object_Iterable;

   procedure Test_Array_Object_Array (Object : in out Test) is
      Text : constant String := "[{""foo"":[true, 42]}]";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Array_Kind, "Not an array");
      Assert (Length (Document) = 1, "Expected length of array to be 1");

      declare
         Element : constant access constant JSON_Value := Get (Document, 1);
      begin
         Assert (Element /= null, "Could not get value at index 1");
         Assert (Kind (Element) = Object_Kind, "First element in array not an object");
         Assert (Length (Element) = 1, "Expected length of object to be 1");

         declare
            Array_Value : constant access constant JSON_Value := Get (Element, "foo");
         begin
            Assert (Array_Value /= null, "Could not get value of 'foo'");
            Assert (Kind (Array_Value) = Array_Kind, "Value of 'foo' not an array");
            Assert (Length (Array_Value) = 2, "Expected length of array 'foo' to be 2");

            declare
               Integer_Value : constant access constant JSON_Value := Get (Array_Value, 2);
            begin
               Assert (Integer_Value /= null, "Could not get value at index 2");
               Assert (Kind (Integer_Value) = Integer_Kind,
                 "Value at index 2 not an integer");
               Assert (Value (Integer_Value) = 42,
                 "Expected integer value at index 2 to be 42");
            end;
         end;
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Array_Object_Array;

   procedure Test_Object_Array_Object (Object : in out Test) is
      Text : constant String := "{""foo"":[null, {""bar"": 42}]}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Object_Kind, "Not an object");
      Assert (Length (Document) = 1, "Expected length of object to be 1");

      declare
         Array_Value : constant access constant JSON_Value := Get (Document, "foo");
      begin
         Assert (Array_Value /= null, "Could not get value of 'foo'");
         Assert (Kind (Array_Value) = Array_Kind, "Element 'foo' in object not an array");
         Assert (Length (Array_Value) = 2, "Expected length of array 'foo' to be 2");

         declare
            Element : constant access constant JSON_Value := Get (Array_Value, 2);
         begin
            Assert (Element /= null, "Could not get value at index 2");
            Assert (Kind (Element) = Object_Kind, "Value of index 2 not an object");
            Assert (Length (Element) = 1, "Expected length of object to be 1");

            declare
               Integer_Value : constant access constant JSON_Value := Get (Element, "bar");
            begin
               Assert (Integer_Value /= null, "Could not get value of 'bar'");
               Assert (Kind (Integer_Value) = Integer_Kind,
                 "Element 'bar' in object not an integer");
               Assert (Value (Integer_Value) = 42, "Expected integer value of 'bar' to be 42");
            end;
         end;
      end;

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Object_Array_Object;

   procedure Test_Object_No_Array (Object : in out Test) is
      Text : constant String := "{}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Object_Kind, "Not an object");
      Assert (not Contains (Document, "foo"), "Expected object not to contain 'foo'");
      Assert (Get (Document, "foo") = null, "Expected no array for key 'foo'");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Object_No_Array;

   procedure Test_Object_No_Object (Object : in out Test) is
      Text : constant String := "{}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      Parsers.Parse (Parser, Document);

      Assert (Kind (Document) = Object_Kind, "Not an object");
      Assert (not Contains (Document, "foo"), "Expected object not to contain 'foo'");
      Assert (Get (Document, "foo") = null, "Expected no object for key 'foo'");

      Free (Document);
      Parsers.Destroy (Parser);
   end Test_Object_No_Object;

   procedure Test_Empty_Text_Exception (Object : in out Test) is
      Text : constant String := "";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Empty_Text_Exception;

   procedure Test_Array_No_Value_Separator_Exception (Object : in out Test) is
      Text : constant String := "[3.14""test""]";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Array_No_Value_Separator_Exception;

   procedure Test_Array_No_End_Array_Exception (Object : in out Test) is
      Text : constant String := "[true";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Array_No_End_Array_Exception;

   procedure Test_No_EOF_After_Array_Exception (Object : in out Test) is
      Text : constant String := "[1]2";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_No_EOF_After_Array_Exception;

   procedure Test_Object_No_Value_Separator_Exception (Object : in out Test) is
      Text : constant String := "{""foo"":1""bar"":2}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Object_No_Value_Separator_Exception;

   procedure Test_Object_No_Name_Separator_Exception (Object : in out Test) is
      Text : constant String := "{""foo"",true}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Object_No_Name_Separator_Exception;

   procedure Test_Object_Key_No_String_Exception (Object : in out Test) is
      Text : constant String := "{42:true}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Object_Key_No_String_Exception;

   procedure Test_Object_No_Second_Member_Exception (Object : in out Test) is
      Text : constant String := "{""foo"":true,}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Object_No_Second_Member_Exception;

   procedure Test_Object_Duplicate_Keys_Exception (Object : in out Test) is
      Text : constant String := "{""foo"":1,""foo"":2}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Object_Duplicate_Keys_Exception;

   procedure Test_Object_No_Value_Exception (Object : in out Test) is
      Text : constant String := "{""foo"":}";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Object_No_Value_Exception;

   procedure Test_Object_No_End_Object_Exception (Object : in out Test) is
      Text : constant String := "{""foo"":true";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_Object_No_End_Object_Exception;

   procedure Test_No_EOF_After_Object_Exception (Object : in out Test) is
      Text : constant String := "{""foo"":true}[true]";

      Parser   : Parsers.Parser;
      Document : aliased JSON_Value_Access;
   begin
      Parsers.Create (Parser, Text);
      begin
         Parsers.Parse (Parser, Document);
         Free (Document);
         Fail ("Expected Parse_Error");
      exception
         when Parsers.Parse_Error =>
            null;
      end;
      Parsers.Destroy (Parser);
   end Test_No_EOF_After_Object_Exception;

end Test_Parsers;
