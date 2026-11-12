import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../main.dart';

class AuthLockScreen extends StatefulWidget {
  final bool isRegistration;

  const AuthLockScreen({super.key, this.isRegistration = false});

  @override
  State<AuthLockScreen> createState() => _AuthLockScreenState();
}

class _AuthLockScreenState extends State<AuthLockScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _enteredMpin = '';
  String _confirmMpin = '';
  bool _isConfirming = false;
  String _errorMessage = '';
  bool _isRegisterMode = false;

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.isRegistration;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    if (_enteredMpin.length < 4) {
      setState(() {
        _errorMessage = '';
        _enteredMpin += digit;
      });

      if (_enteredMpin.length == 4) {
        _handleMpinSubmit();
      }
    }
  }

  void _onBackspace() {
    if (_enteredMpin.isNotEmpty) {
      setState(() {
        _enteredMpin = _enteredMpin.substring(0, _enteredMpin.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _handleMpinSubmit() async {
    if (_isRegisterMode) {
      if (!_isConfirming) {
        setState(() {
          _confirmMpin = _enteredMpin;
          _enteredMpin = '';
          _isConfirming = true;
        });
      } else {
        if (_enteredMpin == _confirmMpin) {
          final phone = _phoneController.text.trim();
          if (phone.length < 10) {
            setState(() {
              _errorMessage = 'Please enter a valid 10-digit mobile number';
              _enteredMpin = '';
              _confirmMpin = '';
              _isConfirming = false;
            });
            return;
          }

          await AuthService.instance.register(phone: phone, mpin: _enteredMpin);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigationShell()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'MPIN does not match. Try again';
            _enteredMpin = '';
            _confirmMpin = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      // Login Mode
      final success = await AuthService.instance.loginWithMpin(_enteredMpin);
      if (success) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationShell()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Incorrect MPIN. Please try again.';
          _enteredMpin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 40),
              ),
              const SizedBox(height: 12),
              Text(
                _isRegisterMode
                    ? (_isConfirming ? 'Confirm 4-Digit MPIN' : 'Secure with Phone & MPIN')
                    : 'Enter 4-Digit MPIN',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                _isRegisterMode
                    ? 'Protect your financial loans, SMS data & account balances'
                    : 'Unlock your Smart Finance Vault',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              if (_isRegisterMode && !_isConfirming) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF10B981)),
                    labelText: 'Mobile Number',
                    prefixText: '+91 ',
                    prefixStyle: const TextStyle(color: Colors.white),
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // MPIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredMpin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isFilled ? const Color(0xFF10B981) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFilled ? const Color(0xFF10B981) : Colors.white30,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_errorMessage, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ],

              const SizedBox(height: 20),

              // Numeric Keypad
              _buildKeypad(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'DEL']
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 64, height: 64);
                }
                if (key == 'DEL') {
                  return InkWell(
                    onTap: _onBackspace,
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      child: const Icon(Icons.backspace_outlined, color: Colors.white),
                    ),
                  );
                }
                return InkWell(
                  onTap: () => _onKeyPress(key),
                  borderRadius: BorderRadius.circular(32),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      key,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
