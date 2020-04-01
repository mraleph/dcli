import 'dart:convert';
import 'dart:io';

import 'package:dshell/dshell.dart';
import 'package:dshell/src/util/wait_for_ex.dart';
import 'package:validators/validators.dart';

import '../settings.dart';

import 'dshell_function.dart';
import 'echo.dart';

///
/// Reads a line of text from stdin with an optional prompt.
///
/// If the user immediately enters newline without
/// entering any text then an empty string will
/// be returned.
///
/// ```dart
/// String response = ask(prompt:"Do you like me?");
/// ```
///
/// In most cases stdin is attached to the console
/// allow you to ask the user to input a value.
///
/// If [prompt] is set then the prompt will be printed
/// to the console and the cursor placed immediately after the prompt.
///
/// if [toLower] is true then the returned result is converted to lower case.
/// This can be useful if you need to compare the entered value.
///
/// If [hidden] is true then the entered values will not be echoed to the
/// console, instead '*' will be displayed. This is uesful for capturing
/// passwords.
/// NOTE: if there is no terminal detected then this will fallback to
/// a standard ask input in which case the hidden characters WILL BE DISPLAYED
/// as they are typed.
///
/// The [validator] is called each time the user hits enter.
/// The [validator] allows you to normalise and validate the user's
/// input. The [validator] must return the normalised value which
/// will be the value returned by [ask].
/// If the [validator] detects an invalid input then you MUST
/// throw [AskException.invalid(error)]. The error will
/// be displayed on the console and the user reprompted.
/// You can color code the error using any of the dshell
/// color functions.  By default all input is considered valid.
///
///```dart
///   var subject = ask(prompt: 'Subject');
///   subject = ask(prompt: 'Subject', validator: Ask.required);
///   subject = ask(prompt: 'Subject', validator: AskMinLength(10));
///   var name = ask(prompt: 'What is your name?', validator: Ask.alpha);
///   var age = ask(prompt: 'How old are you?', validator: Ask.integer);
///   var username = ask(prompt: 'Username?', validator: Ask.email);
///   var password = ask(prompt: 'Password?', hidden: true, validator: AskMultiValidator([Ask.alphaNumeric, AskLength(10,16)]));
///   var color = ask(prompt: 'Favourite colour?', AskListValidator(['red', 'green', 'blue']));
///
///```
String ask(
        {String prompt,
        bool toLower = false,
        bool hidden = false,
        AskValidator validator = Ask.any}) =>
    Ask()._ask(
        prompt: prompt, toLower: toLower, hidden: hidden, validator: validator);

/// [confirm] is a specialized version of ask that returns true or
/// false based on the value entered.
/// Accepted values are y|t|true|yes and n|f|false|no (case insenstiive).
/// If the user enters an unknown value an error is printed
/// and they are reprompted.
bool confirm({String prompt}) {
  bool result;
  var matched = false;

  prompt += ' (y/n):';

  while (!matched) {
    var entered = Ask()
        ._ask(prompt: prompt, toLower: true, hidden: false, validator: Ask.any);
    var lower = entered.toLowerCase();

    if (['y', 't', 'true', 'yes'].contains(lower)) {
      result = true;
      matched = true;
      break;
    }
    if (['n', 'f', 'false', 'no'].contains(lower)) {
      result = false;
      matched = true;
      break;
    }
    print('Invalid value: $entered');
  }
  return result;
}

class Ask extends DShellFunction {
  static const int BACKSPACE = 127;
  static const int SPACE = 32;
  static const int DEL = 8;

  ///
  /// Reads user input from stdin and returns it as a string.
  /// [prompt]
  String _ask(
      {String prompt, bool toLower, bool hidden, AskValidator validator}) {
    Settings().verbose('ask:  ${prompt} toLower: $toLower hidden: $hidden');

    String line;
    var valid = false;
    do {
      if (prompt != null) {
        echo(prompt + ' ', newline: false);
      }

      if (hidden == true && stdin.hasTerminal) {
        line = _readHidden();
      } else {
        line = stdin.readLineSync(
            encoding: Encoding.getByName('utf-8'), retainNewlines: false);
      }

      line ??= '';

      if (toLower == true) {
        line = line.toLowerCase();
      }

      try {
        Settings().verbose('ask: pre validation "${line}"');
        line = validator.validate(line);
        Settings().verbose('ask: post validation "${line}"');
        valid = true;
      } on AskException catch (e) {
        print(e.message);
      }

      Settings().verbose('ask: result ${line}');
    } while (!valid);

    return line;
  }

  String _readHidden() {
    var value = <int>[];

    try {
      stdin.echoMode = false;
      stdin.lineMode = false;
      int char;
      do {
        char = stdin.readByteSync();
        if (char != 10) {
          if (char == BACKSPACE) {
            if (value.isNotEmpty) {
              // move back a character,
              // print a space an move back again.
              // required to clear the current character
              // move back one space.
              stdout.writeCharCode(DEL);
              stdout.writeCharCode(SPACE);
              stdout.writeCharCode(DEL);
              value.removeLast();
            }
          } else {
            stdout.write('*');
            // we must wait for flush as only one flush can be outstanding at a time.
            waitForEx<void>(stdout.flush());
            value.add(char);
          }
        }
      } while (char != 10);
    } finally {
      stdin.echoMode = true;
      stdin.lineMode = true;
    }

    // output a newline as we have suppressed it.
    print('');

    // return the entered value as a String.
    return Encoding.getByName('utf-8').decode(value);
  }

  /// The default validator that considers any input as valid
  static const AskValidator any = AskAny();

  /// The user must enter a non-empty string.
  /// Whitespace will be trimmed before the string is tested.
  static const AskValidator required = AskRequired();

  /// validates that the input is an email address
  static const AskValidator email = AskEmail();

  /// validates that the input is a fully qualified domian name.
  static const AskValidator fqdn = AskFQDN();

  /// validates that the input is a date.
  static const AskValidator date = AskDate();

  /// validates that the input is an integer
  static const AskValidator integer = AskInteger();

  /// validates that the input is a decimal
  static const AskValidator decimal = AskDecimal();

  /// validates that the input is only alpha characters
  static const AskValidator alpha = AskAlpha();

  /// validates that the input is only alphanumeric characters.
  static const AskValidator alphaNumeric = AskAlphaNumeric();

  /// validates that the input is a valid ip address (v4 or v6)
  /// Use the AskIPAddress class directly if you want just a
  /// v4 or v6 address.
  static const AskValidator ipAddress = AskIPAddress();
}

class AskException extends DShellException {
  AskException(String message) : super(message);

  AskException.invalid(String error) : super(error);
}

abstract class AskValidator {
  const AskValidator();
  String validate(String line);
}

/// The default validator that considers any input as valid
class AskAny extends AskValidator {
  const AskAny();
  @override
  String validate(String line) {
    return line;
  }
}

/// The user must enter a non-empty string.
/// Whitespace will be trimmed before the string is tested.
///
class AskRequired extends AskValidator {
  const AskRequired();
  @override
  String validate(String line) {
    line = line.trim();
    if (line.isEmpty) {
      throw AskException.invalid(red('You must enter a value.'));
    }
    return line;
  }
}

class AskEmail extends AskValidator {
  const AskEmail();
  @override
  String validate(String line) {
    line = line.trim();

    if (!isEmail(line)) {
      throw AskException.invalid(red('Invalid email address.'));
    }
    return line;
  }
}

class AskFQDN extends AskValidator {
  const AskFQDN();
  @override
  String validate(String line) {
    line = line.trim();

    if (!isFQDN(line)) {
      throw AskException.invalid(red('Invalid FQDN.'));
    }
    return line;
  }
}

class AskDate extends AskValidator {
  const AskDate();
  @override
  String validate(String line) {
    line = line.trim();

    if (!isDate(line)) {
      throw AskException.invalid(red('Invalid date.'));
    }
    return line;
  }
}

class AskInteger extends AskValidator {
  const AskInteger();
  @override
  String validate(String line) {
    line = line.trim();

    if (!isInt(line)) {
      throw AskException.invalid(red('Invalid integer.'));
    }
    return line;
  }
}

class AskDecimal extends AskValidator {
  const AskDecimal();
  @override
  String validate(String line) {
    line = line.trim();

    if (!isFloat(line)) {
      throw AskException.invalid(red('Invalid decimal number.'));
    }
    return line;
  }
}

class AskAlpha extends AskValidator {
  const AskAlpha();
  @override
  String validate(String line) {
    line = line.trim();

    if (!isAlpha(line)) {
      throw AskException.invalid(red('Alphabetical characters only.'));
    }
    return line;
  }
}

class AskAlphaNumeric extends AskValidator {
  const AskAlphaNumeric();
  @override
  String validate(String line) {
    line = line.trim();

    if (!isAlphanumeric(line)) {
      throw AskException.invalid(red('Alphanumerical characters only.'));
    }
    return line;
  }
}

class AskIPAddress extends AskValidator {
  final int version;

  /// Validates that input is a IP address
  /// By default both v4 and v6 addresses are valid
  /// Pass a [version] to limit the input to one or the
  /// other. If passed [version] must be 4 or 6.
  const AskIPAddress({this.version});

  @override
  String validate(String line) {
    assert(version == null || version == 4 || version == 6);

    line = line.trim();

    if (!isIP(line, version)) {
      throw AskException.invalid(red('Invalid IP Address.'));
    }
    return line;
  }
}

class AskMaxLength extends AskValidator {
  final int maxLength;
  const AskMaxLength(this.maxLength);
  @override
  String validate(String line) {
    line = line.trim();

    if (line.length > maxLength) {
      throw AskException.invalid(red(
          'You have exceeded the maximum length of $maxLength characters.'));
    }
    return line;
  }
}

class AskMinLength extends AskValidator {
  final int minLength;
  const AskMinLength(this.minLength);
  @override
  String validate(String line) {
    line = line.trim();

    if (line.length < minLength) {
      throw AskException.invalid(
          red('You must enter at least $minLength characters.'));
    }
    return line;
  }
}

class AskLength extends AskValidator {
  AskMultiValidator validator;

  AskLength(int minLength, int maxLength) {
    validator = AskMultiValidator([
      AskMinLength(minLength),
      AskMaxLength(maxLength),
    ]);
  }
  @override
  String validate(String line) {
    line = line.trim();

    line = validator.validate(line);
    return line;
  }
}

/// Allows you to combine multiple validators
/// When the user hits enter we apply the list
/// of [valiadators] in the provided order.
/// Validation stops when the first validator fails.
class AskMultiValidator extends AskValidator {
  final List<AskValidator> validators;

  AskMultiValidator(this.validators);
  @override
  String validate(String line) {
    line = line.trim();

    for (var validator in validators) {
      line = validator.validate(line);
    }
    return line;
  }
}

/// Checks that the input matches one of the
/// provided [validItems].
/// If the validator fails it prints out the
/// list of available inputs.
class AskListValidator extends AskValidator {
  final List<String> validItems;

  AskListValidator(this.validItems, {bool caseSensitive = false});
  @override
  String validate(String line) {
    line = line.trim();
    var found = false;
    for (var item in validItems) {
      if (line == item) {
        found = true;
        break;
      }
    }
    if (!found) {
      throw AskException.invalid(
          red('The valid responses are ${validItems.join(' | ')}.'));
    }

    return line;
  }
}
