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

with Ada.Characters.Latin_1;

package body JSON.Tokenizers with SPARK_Mode => On is

   use type Types.Integer_Type;
   use type Types.Float_Type;

   function Error_Message (Status : Token_Status) return String is
     (case Status is
        when Error_Unexpected_EOF =>
          "Unexpectedly read EOF",
        when Error_Expected_EOF =>
          "Expected to read EOF",
        when Error_Unexpected_Character =>
          "Unexpected character",
        when Error_Control_Character =>
          "Unexpected control character in string",
        when Error_Escaped_Character =>
          "Unexpected escaped character in string",
        when Error_Escaped_Unicode =>
          "Invalid \u escape sequence in string",
        when Error_Plus_Sign =>
          "Prefixing number with '+' character is not allowed",
        when Error_Leading_Zeroes =>
          "Leading zeroes in number are not allowed",
        when Error_Minus_Digit =>
          "Expected at least one digit after - sign",
        when Error_Dot_Digit =>
          "Number must contain at least one digit after decimal point",
        when Error_Exponent_Digit =>
          "Expected optional +/- sign after e/E and then at least one digit",
        when Error_Exponent_Sign_Digit =>
          "Expected at least one digit after +/- sign in number",
        when Error_Number_Too_Long =>
          "Number is too long",
        when Error_Number_Out_Of_Range =>
          "Number is out of range of its type",
        when Error_Invalid_Literal =>
          "Expected literal 'true', 'false', or 'null'",
        when Success =>
          raise Program_Error);

   procedure Scan_Hex_Quad
     (Stream : in out Streams.Stream;
      Count  : in out Natural;
      Unit   : out Natural;
      Status : out Token_Status)
   with Pre  => not Streams.Has_Buffered_Character (Stream)
                  and then Count <= Streams.Position (Stream) - 1,
        Always_Terminates,
        Post =>
     Streams.Length (Stream) = Streams.Length (Stream)'Old
       and then not Streams.Has_Buffered_Character (Stream)
       and then Streams.Position (Stream) >= Streams.Position (Stream)'Old
       and then Count <= Streams.Position (Stream) - 1
       and then (if Status = Success then Unit <= 16#FFFF#)
   --  Scan the 4 hexadecimal digits of a \uXXXX escape sequence and
   --  return their value as a UTF-16 code unit
   is
      function To_Hex_Digit (Value : Character) return Natural is
        (case Value is
           when '0' .. '9' => Character'Pos (Value) - Character'Pos ('0'),
           when 'a' .. 'f' => Character'Pos (Value) - Character'Pos ('a') + 10,
           when 'A' .. 'F' => Character'Pos (Value) - Character'Pos ('A') + 10,
           when others     => 0)
      with Post => To_Hex_Digit'Result <= 15;

      C   : Character;
      EOF : Boolean;
   begin
      Unit := 0;
      Status := Success;

      for J in 1 .. 4 loop
         pragma Loop_Invariant (not Streams.Has_Buffered_Character (Stream));
         pragma Loop_Invariant
           (Streams.Length (Stream) = Streams.Length (Stream)'Loop_Entry);
         pragma Loop_Invariant
           (Streams.Position (Stream) >= Streams.Position (Stream)'Loop_Entry);
         pragma Loop_Invariant (Count <= Streams.Position (Stream) - 1);
         pragma Loop_Invariant (Unit < 16 ** (J - 1));

         Streams.Read_Character (Stream, C, EOF);
         if EOF then
            Status := Error_Unexpected_EOF;
            return;
         end if;
         Count := Count + 1;

         if C not in '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' then
            Status := Error_Escaped_Unicode;
            return;
         end if;

         Unit := Unit * 16 + To_Hex_Digit (C);
      end loop;
   end Scan_Hex_Quad;

   procedure Scan_String
     (Stream     : in out Streams.Stream;
      Next_Token : out Token;
      Status     : out Token_Status)
   with Pre  => not Streams.Has_Buffered_Character (Stream),
        Always_Terminates,
        Post =>
     Streams.Length (Stream) = Streams.Length (Stream)'Old
       and then not Streams.Has_Buffered_Character (Stream)
       and then Streams.Position (Stream) >= Streams.Position (Stream)'Old
       and then (if Status = Success then
                   Next_Token.Kind = String_Token
                     and then Streams.Valid_Span
                       (Stream, Next_Token.String_Offset, Next_Token.String_Length))
   is
      C       : Character;
      EOF     : Boolean;
      Index   : Positive;
      Count   : Natural := 0;
      Escaped : Boolean := False;
   begin
      Next_Token := (Kind => Invalid_Token, others => <>);
      Status := Success;

      loop
         pragma Loop_Invariant (not Streams.Has_Buffered_Character (Stream));
         pragma Loop_Invariant
           (Streams.Length (Stream) = Streams.Length (Stream)'Loop_Entry);
         pragma Loop_Invariant (Count <= Streams.Position (Stream) - 1);
         pragma Loop_Invariant
           (Streams.Position (Stream) >= Streams.Position (Stream)'Loop_Entry);
         pragma Loop_Variant (Increases => Streams.Position (Stream));

         Streams.Read_Character (Stream, Index, C, EOF);
         if EOF then
            Status := Error_Unexpected_EOF;
            return;
         end if;

         --  An unescaped '"' character denotes the end of the string
         exit when not Escaped and C = '"';

         Count := Count + 1;

         if Escaped then
            case C is
               when '"' | '\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' =>
                  null;
               when 'u' =>
                  --  A \uXXXX escape sequence: scan the 4 hexadecimal
                  --  digits. JSON strings encode code points beyond the
                  --  Basic Multilingual Plane as a UTF-16 surrogate
                  --  pair (RFC 8259 section 7), so a high surrogate
                  --  must be followed by \u and a low surrogate, and a
                  --  lone surrogate is invalid.
                  declare
                     Unit : Natural;
                  begin
                     Scan_Hex_Quad (Stream, Count, Unit, Status);
                     if Status /= Success then
                        return;
                     end if;

                     if Unit in 16#DC00# .. 16#DFFF# then
                        --  A low surrogate without a preceding high
                        --  surrogate
                        Status := Error_Escaped_Unicode;
                        return;
                     elsif Unit in 16#D800# .. 16#DBFF# then
                        Streams.Read_Character (Stream, C, EOF);
                        if EOF then
                           Status := Error_Unexpected_EOF;
                           return;
                        end if;
                        Count := Count + 1;
                        if C /= '\' then
                           Status := Error_Escaped_Unicode;
                           return;
                        end if;

                        Streams.Read_Character (Stream, C, EOF);
                        if EOF then
                           Status := Error_Unexpected_EOF;
                           return;
                        end if;
                        Count := Count + 1;
                        if C /= 'u' then
                           Status := Error_Escaped_Unicode;
                           return;
                        end if;

                        Scan_Hex_Quad (Stream, Count, Unit, Status);
                        if Status /= Success then
                           return;
                        end if;
                        if Unit not in 16#DC00# .. 16#DFFF# then
                           Status := Error_Escaped_Unicode;
                           return;
                        end if;
                     end if;
                  end;
               when others =>
                  Status := Error_Escaped_Character;
                  return;
            end case;
         elsif C /= '\' then
            --  Check C is not a control character
            if Character'Pos (C) <= 31 then
               Status := Error_Control_Character;
               return;
            end if;
         end if;
         Escaped := not Escaped and C = '\';
      end loop;

      Next_Token :=
        (Kind          => String_Token,
         String_Offset => Index - Count,
         String_Length => Count,
         others        => <>);
   end Scan_String;

   procedure Scan_Number
     (Stream     : in out Streams.Stream;
      First      : Character;
      Next_Token : out Token;
      Status     : out Token_Status)
   with Pre  => not Streams.Has_Buffered_Character (Stream)
                  and then First in '0' .. '9' | '+' | '-',
        Always_Terminates,
        Post =>
     Streams.Length (Stream) = Streams.Length (Stream)'Old
       and then Streams.Position (Stream) >= Streams.Position (Stream)'Old
       and then (if Streams.Has_Buffered_Character (Stream) then
                   Streams.Position (Stream) > Streams.Position (Stream)'Old)
       and then (if Status = Success then
                   Next_Token.Kind in Integer_Token | Float_Token)
   is
      subtype Base_Integer is Types.Integer_Type'Base;
      subtype Base_Float is Types.Float_Type'Base;

      --  Base_Float'Last / 16.0 is exact (division by a power of two),
      --  which makes the overflow guards below provable
      Mantissa_Limit : constant Base_Float := Base_Float'Last / 16.0;

      --  Beyond this value the exponent saturates: the result is the
      --  same (zero, or out of range) for all larger exponents, because
      --  the mantissa has at most Maximum_Number_Length digits
      Exp_Limit : constant := 100_000;

      C   : Character;
      EOF : Boolean;

      Char_Count : Natural;

      Is_Negative : constant Boolean := First = '-';
      Is_Float    : Boolean := False;

      Int_Acc      : Base_Integer := 0;  --  Accumulated as a non-positive value
      Int_Overflow : Boolean := False;

      F_Acc      : Base_Float := 0.0;    --  Accumulated absolute mantissa
      F_Overflow : Boolean := False;

      Int_Digits  : Natural   := 0;
      First_Digit : Character := '0';

      Frac_Digits : Natural := 0;

      Exp_Value    : Natural := 0;       --  Saturated at Exp_Limit
      Exp_Negative : Boolean := False;

      function To_Digit (Value : Character) return Base_Integer is
        (Character'Pos (Value) - Character'Pos ('0'))
      with Pre => Value in '0' .. '9';

      procedure Add_Digit (Digit : Base_Integer)
        with Pre  => Digit in 0 .. 9
                       and then Int_Acc <= 0
                       and then F_Acc in 0.0 .. Mantissa_Limit * 10.0 + 9.0,
             Always_Terminates,
             Post => Int_Acc <= 0
                       and then F_Acc in 0.0 .. Mantissa_Limit * 10.0 + 9.0
      is
      begin
         if not Int_Overflow then
            if Int_Acc < (Base_Integer'First + Digit) / 10 then
               Int_Overflow := True;
            else
               Int_Acc := Int_Acc * 10 - Digit;
            end if;
         end if;

         if not F_Overflow then
            if F_Acc > Mantissa_Limit then
               F_Overflow := True;
            else
               F_Acc := F_Acc * 10.0 + Base_Float (Digit);
            end if;
         end if;
      end Add_Digit;
   begin
      Next_Token := (Kind => Invalid_Token, others => <>);
      Status := Success;

      if First = '+' then
         Status := Error_Plus_Sign;
         return;
      end if;

      Char_Count := 1;

      if not Is_Negative then
         First_Digit := First;
         Int_Digits := 1;
         Add_Digit (To_Digit (First));
      end if;

      --  Accept a sequence of digits for the integer part
      loop
         pragma Loop_Invariant (not Streams.Has_Buffered_Character (Stream));
         pragma Loop_Invariant
           (Streams.Length (Stream) = Streams.Length (Stream)'Loop_Entry);
         pragma Loop_Invariant
           (Int_Acc <= 0 and F_Acc in 0.0 .. Mantissa_Limit * 10.0 + 9.0);
         pragma Loop_Invariant (Char_Count <= Types.Maximum_String_Length_Numbers);
         pragma Loop_Invariant (Int_Digits <= Char_Count);
         pragma Loop_Invariant
           (Streams.Position (Stream) >= Streams.Position (Stream)'Loop_Entry);
         pragma Loop_Variant (Increases => Streams.Position (Stream));

         Streams.Read_Character (Stream, C, EOF);
         exit when EOF or else C not in '0' .. '9';

         if Char_Count = Types.Maximum_String_Length_Numbers then
            Status := Error_Number_Too_Long;
            return;
         end if;
         Char_Count := Char_Count + 1;

         if Int_Digits = 0 then
            First_Digit := C;
         end if;
         Int_Digits := Int_Digits + 1;
         Add_Digit (To_Digit (C));
      end loop;

      --  Test for a missing digit after a '-' sign and for leading zeroes
      if Int_Digits = 0 then
         Status := Error_Minus_Digit;
         return;
      elsif First_Digit = '0' and then Int_Digits >= 2 then
         Status := Error_Leading_Zeroes;
         return;
      end if;

      --  Fraction part
      if not EOF and then C = '.' then
         Is_Float := True;

         if Char_Count = Types.Maximum_String_Length_Numbers then
            Status := Error_Number_Too_Long;
            return;
         end if;
         Char_Count := Char_Count + 1;

         --  Require at least one digit after the decimal point
         Streams.Read_Character (Stream, C, EOF);
         if EOF or else C not in '0' .. '9' then
            Status := Error_Dot_Digit;
            return;
         end if;

         if Char_Count = Types.Maximum_String_Length_Numbers then
            Status := Error_Number_Too_Long;
            return;
         end if;
         Char_Count := Char_Count + 1;

         Frac_Digits := 1;
         Add_Digit (To_Digit (C));

         --  Accept a sequence of digits
         loop
            pragma Loop_Invariant (not Streams.Has_Buffered_Character (Stream));
            pragma Loop_Invariant
              (Streams.Length (Stream) = Streams.Length (Stream)'Loop_Entry);
            pragma Loop_Invariant
              (Int_Acc <= 0 and F_Acc in 0.0 .. Mantissa_Limit * 10.0 + 9.0);
            pragma Loop_Invariant
              (Char_Count <= Types.Maximum_String_Length_Numbers);
            pragma Loop_Invariant (Frac_Digits < Char_Count + 1);
            pragma Loop_Invariant
              (Streams.Position (Stream) >= Streams.Position (Stream)'Loop_Entry);
            pragma Loop_Variant (Increases => Streams.Position (Stream));

            Streams.Read_Character (Stream, C, EOF);
            exit when EOF or else C not in '0' .. '9';

            if Char_Count = Types.Maximum_String_Length_Numbers then
               Status := Error_Number_Too_Long;
               return;
            end if;
            Char_Count := Char_Count + 1;

            Frac_Digits := Frac_Digits + 1;
            Add_Digit (To_Digit (C));
         end loop;
      end if;

      --  Exponent part
      if not EOF and then C in 'e' | 'E' then
         if Char_Count = Types.Maximum_String_Length_Numbers then
            Status := Error_Number_Too_Long;
            return;
         end if;
         Char_Count := Char_Count + 1;

         Streams.Read_Character (Stream, C, EOF);
         if EOF then
            Status := Error_Exponent_Digit;
            return;
         end if;

         --  Accept an optional '+' or '-' character
         if C in '+' | '-' then
            --  If the exponent is negative, the number will be a float
            if C = '-' then
               Exp_Negative := True;
               Is_Float := True;
            end if;

            if Char_Count = Types.Maximum_String_Length_Numbers then
               Status := Error_Number_Too_Long;
               return;
            end if;
            Char_Count := Char_Count + 1;

            --  Require at least one digit after the +/- sign
            Streams.Read_Character (Stream, C, EOF);
            if EOF or else C not in '0' .. '9' then
               Status := Error_Exponent_Sign_Digit;
               return;
            end if;
         elsif C not in '0' .. '9' then
            Status := Error_Exponent_Digit;
            return;
         end if;

         if Char_Count = Types.Maximum_String_Length_Numbers then
            Status := Error_Number_Too_Long;
            return;
         end if;
         Char_Count := Char_Count + 1;

         Exp_Value := Natural (To_Digit (C));

         --  Accept a sequence of digits
         loop
            pragma Loop_Invariant (not Streams.Has_Buffered_Character (Stream));
            pragma Loop_Invariant
              (Streams.Length (Stream) = Streams.Length (Stream)'Loop_Entry);
            pragma Loop_Invariant
              (Int_Acc <= 0 and F_Acc in 0.0 .. Mantissa_Limit * 10.0 + 9.0);
            pragma Loop_Invariant
              (Char_Count <= Types.Maximum_String_Length_Numbers);
            pragma Loop_Invariant (Exp_Value <= Exp_Limit);
            pragma Loop_Invariant
              (Streams.Position (Stream) >= Streams.Position (Stream)'Loop_Entry);
            pragma Loop_Variant (Increases => Streams.Position (Stream));

            Streams.Read_Character (Stream, C, EOF);
            exit when EOF or else C not in '0' .. '9';

            if Char_Count = Types.Maximum_String_Length_Numbers then
               Status := Error_Number_Too_Long;
               return;
            end if;
            Char_Count := Char_Count + 1;

            if Exp_Value <= (Exp_Limit - 9) / 10 then
               Exp_Value := Exp_Value * 10 + Natural (To_Digit (C));
            else
               Exp_Value := Exp_Limit;
            end if;
         end loop;
      end if;

      --  Buffer the character that terminated the number
      if not EOF then
         Streams.Write_Character (Stream, C);
      end if;

      if Is_Float then
         if F_Overflow then
            Status := Error_Number_Out_Of_Range;
            return;
         end if;

         declare
            Scale : constant Integer :=
              (if Exp_Negative then -Exp_Value else Exp_Value) - Frac_Digits;
            F_Val : Base_Float := F_Acc;
         begin
            if F_Val /= 0.0 then
               if Scale > 0 then
                  for J in 1 .. Scale loop
                     pragma Loop_Invariant
                       (F_Val in 0.0 .. Mantissa_Limit * 10.0 + 9.0);

                     if F_Val > Mantissa_Limit then
                        Status := Error_Number_Out_Of_Range;
                        return;
                     end if;
                     F_Val := F_Val * 10.0;
                  end loop;
               elsif Scale < 0 then
                  --  The divisor is built up exactly and applied in a
                  --  single division where possible, so that small
                  --  decimal numbers like 3.14 convert with a single
                  --  rounding. Power_Limit is exact (a division by a
                  --  power of two), which makes the guards provable.
                  declare
                     Power_Limit : constant Base_Float := Base_Float'Last / 256.0;
                     P           : Base_Float := 1.0;
                  begin
                     for J in 1 .. -Scale loop
                        pragma Loop_Invariant (P >= 1.0);
                        pragma Loop_Invariant (P <= Power_Limit * 10.0);
                        pragma Loop_Invariant
                          (F_Val in 0.0 .. Mantissa_Limit * 10.0 + 9.0);

                        if P > Power_Limit then
                           F_Val := F_Val / P;
                           P := 1.0;
                        end if;
                        P := P * 10.0;
                     end loop;
                     pragma Assert (P >= 1.0);
                     F_Val := F_Val / P;
                  end;
               end if;
            end if;

            declare
               Signed : constant Base_Float :=
                 (if Is_Negative then -F_Val else F_Val);
            begin
               if Signed in Types.Float_Type'First .. Types.Float_Type'Last then
                  Next_Token :=
                    (Kind => Float_Token, Float_Value => Signed, others => <>);
               else
                  Status := Error_Number_Out_Of_Range;
                  return;
               end if;
            end;
         end;
      else
         if Int_Overflow then
            Status := Error_Number_Out_Of_Range;
            return;
         end if;

         if Exp_Value > 0 and Int_Acc /= 0 then
            for J in 1 .. Exp_Value loop
               pragma Loop_Invariant (Int_Acc <= 0);

               if Int_Acc < Base_Integer'First / 10 then
                  Status := Error_Number_Out_Of_Range;
                  return;
               end if;
               Int_Acc := Int_Acc * 10;
            end loop;
         end if;

         declare
            Signed : Base_Integer;
         begin
            if Is_Negative then
               Signed := Int_Acc;
            else
               if Int_Acc < -Base_Integer'Last then
                  Status := Error_Number_Out_Of_Range;
                  return;
               end if;
               Signed := -Int_Acc;
            end if;

            if Signed in Types.Integer_Type'First .. Types.Integer_Type'Last then
               Next_Token :=
                 (Kind => Integer_Token, Integer_Value => Signed, others => <>);
            else
               Status := Error_Number_Out_Of_Range;
               return;
            end if;
         end;
      end if;
   end Scan_Number;

   procedure Scan_Literal
     (Stream     : in out Streams.Stream;
      First      : Character;
      Next_Token : out Token;
      Status     : out Token_Status)
   with Pre  => not Streams.Has_Buffered_Character (Stream),
        Always_Terminates,
        Post =>
     Streams.Length (Stream) = Streams.Length (Stream)'Old
       and then Streams.Position (Stream) >= Streams.Position (Stream)'Old
       and then (if Streams.Has_Buffered_Character (Stream) then
                   Streams.Position (Stream) > Streams.Position (Stream)'Old)
       and then (if Status = Success then
                   Next_Token.Kind in Boolean_Token | Null_Token)
   is
      Buffer : String (1 .. 5) := (others => ' ');
      Last   : Natural range 0 .. 5;

      C   : Character;
      EOF : Boolean;
   begin
      Next_Token := (Kind => Invalid_Token, others => <>);
      Status := Success;

      Buffer (1) := First;
      Last := 1;

      loop
         pragma Loop_Invariant (not Streams.Has_Buffered_Character (Stream));
         pragma Loop_Invariant
           (Streams.Length (Stream) = Streams.Length (Stream)'Loop_Entry);
         pragma Loop_Invariant (Last in 1 .. 5);
         pragma Loop_Invariant
           (Streams.Position (Stream) >= Streams.Position (Stream)'Loop_Entry);
         pragma Loop_Variant (Increases => Streams.Position (Stream));

         Streams.Read_Character (Stream, C, EOF);
         exit when EOF;
         exit when C not in 'a' .. 'z' or else Last = 5;
         Last := Last + 1;
         Buffer (Last) := C;
      end loop;

      if not EOF then
         Streams.Write_Character (Stream, C);
      end if;

      if Buffer (1 .. Last) = "true" then
         Next_Token := (Kind => Boolean_Token, Boolean_Value => True, others => <>);
      elsif Buffer (1 .. Last) = "false" then
         Next_Token := (Kind => Boolean_Token, Boolean_Value => False, others => <>);
      elsif Buffer (1 .. Last) = "null" then
         Next_Token := (Kind => Null_Token, others => <>);
      else
         Status := Error_Invalid_Literal;
      end if;
   end Scan_Literal;

   procedure Scan_Token
     (Stream     : in out Streams.Stream;
      Next_Token : out Token;
      Status     : out Token_Status;
      Expect_EOF : Boolean := False)
   is
      use Ada.Characters.Latin_1;

      C   : Character;
      EOF : Boolean;
   begin
      Next_Token := (Kind => Invalid_Token, others => <>);
      Status := Success;

      loop
         pragma Loop_Invariant
           (Streams.Length (Stream) = Streams.Length (Stream)'Loop_Entry);
         pragma Loop_Invariant
           (Streams.Position (Stream) >= Streams.Position (Stream)'Loop_Entry);
         pragma Loop_Invariant
           (if Streams.Has_Buffered_Character (Stream)
              and then Streams.Position (Stream) = Streams.Position (Stream)'Loop_Entry
            then Streams.Has_Buffered_Character (Stream)'Loop_Entry);
         pragma Loop_Variant
           (Decreases =>
              Streams.Length (Stream) - Streams.Position (Stream) + 1
                + (if Streams.Has_Buffered_Character (Stream) then 1 else 0));

         --  Read the next character and decide which token it could be
         --  part of, skipping whitespace
         Streams.Read_Character (Stream, C, EOF);
         exit when EOF or else C not in ' ' | HT | LF | CR;
      end loop;

      if EOF then
         if Expect_EOF then
            Next_Token := (Kind => EOF_Token, others => <>);
         else
            Status := Error_Unexpected_EOF;
         end if;
         return;
      end if;

      if Expect_EOF then
         Status := Error_Expected_EOF;
         return;
      end if;

      case C is
         when '[' =>
            Next_Token := (Kind => Begin_Array_Token, others => <>);
         when '{' =>
            Next_Token := (Kind => Begin_Object_Token, others => <>);
         when ']' =>
            Next_Token := (Kind => End_Array_Token, others => <>);
         when '}' =>
            Next_Token := (Kind => End_Object_Token, others => <>);
         when ':' =>
            Next_Token := (Kind => Name_Separator_Token, others => <>);
         when ',' =>
            Next_Token := (Kind => Value_Separator_Token, others => <>);
         when '"' =>
            Scan_String (Stream, Next_Token, Status);
         when '0' .. '9' | '+' | '-' =>
            Scan_Number (Stream, C, Next_Token, Status);
         when 'a' .. 'z' =>
            Scan_Literal (Stream, C, Next_Token, Status);
         when others =>
            Status := Error_Unexpected_Character;
      end case;
   end Scan_Token;

   procedure Read_Token
     (Stream     : in out Streams.Stream;
      Next_Token : out Token;
      Expect_EOF : Boolean := False)
   is
      Status : Token_Status;
   begin
      Scan_Token (Stream, Next_Token, Status, Expect_EOF);
      if Status /= Success then
         raise Tokenizer_Error with Error_Message (Status);
      end if;
   end Read_Token;

end JSON.Tokenizers;
