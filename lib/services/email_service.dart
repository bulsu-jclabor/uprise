// lib/email_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // 👇 I-PASTE DITO ANG RESEND API KEY MO
  static const String _apiKey = 're_Z21o6Yi3_NXiu1B1SP3FjNtTtqGaUhM7R';
  
  static Future<bool> sendCredentialsEmail({
    required String toEmail,
    required String toName,
    required String orgName,
    required String tempPassword,
  }) async {
    try {
      print('📧 Sending email to: $toEmail');
      
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'UPRISE System <onboarding@resend.dev>', // Libreng sender ito!
          'to': [toEmail],
          'subject': '🎓 UPRISE Portal - Your Login Credentials',
          'html': '''
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="UTF-8">
              <style>
                body {
                  font-family: 'Segoe UI', Arial, sans-serif;
                  margin: 0;
                  padding: 0;
                  background-color: #f4f4f4;
                }
                .container {
                  max-width: 600px;
                  margin: 20px auto;
                  background: white;
                  border-radius: 12px;
                  overflow: hidden;
                  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                .header {
                  background: linear-gradient(135deg, #D97706, #B45309);
                  padding: 30px;
                  text-align: center;
                }
                .header h1 {
                  color: white;
                  margin: 0;
                  font-size: 28px;
                }
                .header p {
                  color: rgba(255,255,255,0.9);
                  margin: 5px 0 0;
                }
                .content {
                  padding: 30px;
                }
                .greeting {
                  font-size: 18px;
                  color: #333;
                  margin-bottom: 20px;
                }
                .credentials {
                  background: #FFF7ED;
                  border-left: 4px solid #D97706;
                  padding: 20px;
                  margin: 25px 0;
                  border-radius: 8px;
                }
                .credentials p {
                  margin: 10px 0;
                  font-size: 15px;
                }
                .password {
                  font-family: monospace;
                  font-size: 20px;
                  font-weight: bold;
                  color: #D97706;
                  background: white;
                  padding: 8px 12px;
                  border-radius: 6px;
                  display: inline-block;
                }
                .warning {
                  background: #FEF3C7;
                  padding: 15px;
                  border-radius: 8px;
                  margin: 20px 0;
                  font-size: 14px;
                  color: #92400E;
                }
                .footer {
                  background: #F8FAFC;
                  padding: 20px;
                  text-align: center;
                  font-size: 12px;
                  color: #666;
                  border-top: 1px solid #E2E8F0;
                }
                button {
                  background: #D97706;
                  color: white;
                  padding: 12px 24px;
                  border: none;
                  border-radius: 6px;
                  cursor: pointer;
                  font-size: 14px;
                }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="header">
                  <h1>🎓 UPRISE Portal</h1>
                  <p>CICT Organization Management System</p>
                </div>
                <div class="content">
                  <div class="greeting">
                    Hello <strong>$toName</strong>!
                  </div>
                  
                  <p>Your organization <strong>$orgName</strong> has been successfully registered on the UPRISE Portal.</p>
                  
                  <div class="credentials">
                    <p><strong>📧 Email Address:</strong> $toEmail</p>
                    <p><strong>🔑 Temporary Password:</strong></p>
                    <p><span class="password">$tempPassword</span></p>
                  </div>
                  
                  <div class="warning">
                    <strong>⚠️ IMPORTANT:</strong>
                    <ul style="margin: 10px 0 0 20px;">
                      <li>This is your temporary password</li>
                      <li>Please change your password after first login</li>
                      <li>Do not share this password with anyone</li>
                    </ul>
                  </div>
                  
                  <p style="text-align: center; margin-top: 30px;">
                    <a href="[your-app-login-url]" style="background: #D97706; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                      Login to UPRISE →
                    </a>
                  </p>
                </div>
                <div class="footer">
                  <p>© 2024 UPRISE — CICT Organization Management System</p>
                  <p>This is an automated message, please do not reply.</p>
                  <p style="font-size: 11px; margin-top: 10px;">
                    If you did not request this email, please ignore it.
                  </p>
                </div>
              </div>
            </body>
            </html>
          ''',
        }),
      );
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('✅ Email sent successfully!');
        return true;
      } else {
        print('❌ Failed to send email: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }
  
  // Test function para malaman kung gumagana
  static Future<bool> sendTestEmail(String toEmail) async {
    return sendCredentialsEmail(
      toEmail: toEmail,
      toName: 'Test User',
      orgName: 'Test Organization',
      tempPassword: 'TestPass123',
    );
  }
}