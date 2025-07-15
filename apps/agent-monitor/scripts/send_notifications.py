#!/usr/bin/env python3
"""
Send agent status report notifications via Slack and Email
"""

import os
import sys
import json
import smtplib
import requests
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from pathlib import Path

# Configuration
SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL', '{{SLACK_WEBHOOK_URL}}')
EMAIL_SMTP_SERVER = os.environ.get('EMAIL_SMTP_SERVER', 'smtp.gmail.com')
EMAIL_SMTP_PORT = int(os.environ.get('EMAIL_SMTP_PORT', '587'))
EMAIL_FROM = os.environ.get('EMAIL_FROM', '{{EMAIL_FROM}}')
EMAIL_PASSWORD = os.environ.get('EMAIL_PASSWORD', '{{EMAIL_PASSWORD}}')
EMAIL_TO = os.environ.get('EMAIL_TO', '{{EMAIL_TO}}').split(',')
REPORT_URL = os.environ.get('REPORT_URL', 'https://zippycoin.internal/reports/latest')

def read_latest_report():
    """Read the latest report from the reports directory"""
    reports_dir = Path('../reports')
    report_files = list(reports_dir.glob('agent_status_*.md'))
    
    if not report_files:
        raise FileNotFoundError("No report files found")
    
    latest_report = max(report_files, key=lambda x: x.stat().st_mtime)
    
    with open(latest_report, 'r') as f:
        content = f.read()
    
    return latest_report.name, content

def extract_summary(report_content):
    """Extract key metrics from the report"""
    lines = report_content.split('\n')
    summary = {
        'overall_completion': None,
        'active_agents': None,
        'critical_issues': None,
        'warnings': None,
        'offline_agents': []
    }
    
    for line in lines:
        if 'Overall Project Completion' in line:
            summary['overall_completion'] = line.split(':')[1].strip()
        elif 'Critical Issues:' in line:
            summary['critical_issues'] = line.split(':')[1].strip()
        elif 'Warnings:' in line:
            summary['warnings'] = line.split(':')[1].strip()
        elif 'Agents Offline:' in line:
            summary['offline_agents_count'] = line.split(':')[1].strip()
    
    # Extract offline agents
    in_table = False
    for line in lines:
        if '| Agent ID |' in line:
            in_table = True
            continue
        if in_table and line.strip() and '|' in line:
            parts = [p.strip() for p in line.split('|')]
            if len(parts) > 3 and '🔴' in parts[3]:
                summary['offline_agents'].append({
                    'id': parts[1],
                    'name': parts[2]
                })
    
    return summary

def send_slack_notification(report_name, summary):
    """Send notification to Slack"""
    if SLACK_WEBHOOK_URL == '{{SLACK_WEBHOOK_URL}}':
        print("Slack webhook URL not configured. Skipping Slack notification.")
        return False
    
    # Format message
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"📊 Agent Status Report - {datetime.now().strftime('%Y-%m-%d')}"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*Overall Completion:*\n{summary['overall_completion']}"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Critical Issues:*\n{summary['critical_issues']}"
                }
            ]
        }
    ]
    
    # Add offline agents if any
    if summary['offline_agents']:
        offline_text = "⚠️ *Offline Agents:*\n"
        for agent in summary['offline_agents']:
            offline_text += f"• {agent['id']}: {agent['name']}\n"
        
        blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": offline_text
            }
        })
    
    # Add action buttons
    blocks.append({
        "type": "actions",
        "elements": [
            {
                "type": "button",
                "text": {
                    "type": "plain_text",
                    "text": "View Full Report"
                },
                "url": REPORT_URL,
                "style": "primary"
            }
        ]
    })
    
    payload = {
        "blocks": blocks,
        "text": f"Agent Status Report - Overall Completion: {summary['overall_completion']}"
    }
    
    try:
        response = requests.post(SLACK_WEBHOOK_URL, json=payload)
        response.raise_for_status()
        print("✅ Slack notification sent successfully")
        return True
    except Exception as e:
        print(f"❌ Failed to send Slack notification: {e}")
        return False

def send_email_notification(report_name, summary, report_content):
    """Send notification via email"""
    if EMAIL_FROM == '{{EMAIL_FROM}}' or EMAIL_PASSWORD == '{{EMAIL_PASSWORD}}':
        print("Email credentials not configured. Skipping email notification.")
        return False
    
    # Create message
    msg = MIMEMultipart('alternative')
    msg['Subject'] = f'Agent Status Report - {datetime.now().strftime("%Y-%m-%d")}'
    msg['From'] = EMAIL_FROM
    msg['To'] = ', '.join(EMAIL_TO)
    
    # Create HTML content
    html = f"""
    <html>
      <body style="font-family: Arial, sans-serif;">
        <h2>📊 Agent Status Report - {datetime.now().strftime('%Y-%m-%d')}</h2>
        
        <table style="border-collapse: collapse; margin: 20px 0;">
          <tr>
            <td style="padding: 10px; border: 1px solid #ddd;"><strong>Overall Completion:</strong></td>
            <td style="padding: 10px; border: 1px solid #ddd;">{summary['overall_completion']}</td>
          </tr>
          <tr>
            <td style="padding: 10px; border: 1px solid #ddd;"><strong>Critical Issues:</strong></td>
            <td style="padding: 10px; border: 1px solid #ddd; color: #d32f2f;">{summary['critical_issues']}</td>
          </tr>
          <tr>
            <td style="padding: 10px; border: 1px solid #ddd;"><strong>Warnings:</strong></td>
            <td style="padding: 10px; border: 1px solid #ddd; color: #f57c00;">{summary['warnings']}</td>
          </tr>
        </table>
    """
    
    if summary['offline_agents']:
        html += """
        <h3>⚠️ Offline Agents:</h3>
        <ul>
        """
        for agent in summary['offline_agents']:
            html += f"<li><strong>{agent['id']}</strong>: {agent['name']}</li>"
        html += "</ul>"
    
    html += f"""
        <p style="margin-top: 30px;">
          <a href="{REPORT_URL}" style="background-color: #1976d2; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
            View Full Report
          </a>
        </p>
        
        <hr style="margin-top: 40px;">
        <p style="color: #666; font-size: 12px;">
          This is an automated notification from the ZippyCoin Agent Monitor System.
        </p>
      </body>
    </html>
    """
    
    # Attach both plain text and HTML versions
    text_part = MIMEText(report_content, 'plain')
    html_part = MIMEText(html, 'html')
    
    msg.attach(text_part)
    msg.attach(html_part)
    
    try:
        # Send email
        with smtplib.SMTP(EMAIL_SMTP_SERVER, EMAIL_SMTP_PORT) as server:
            server.starttls()
            server.login(EMAIL_FROM, EMAIL_PASSWORD)
            server.send_message(msg)
        
        print(f"✅ Email sent successfully to: {', '.join(EMAIL_TO)}")
        return True
    except Exception as e:
        print(f"❌ Failed to send email: {e}")
        return False

def main():
    """Main function"""
    try:
        # Read latest report
        report_name, report_content = read_latest_report()
        print(f"📄 Processing report: {report_name}")
        
        # Extract summary
        summary = extract_summary(report_content)
        
        # Send notifications
        slack_success = send_slack_notification(report_name, summary)
        email_success = send_email_notification(report_name, summary, report_content)
        
        if slack_success or email_success:
            print("\n✅ Notifications sent successfully!")
            return 0
        else:
            print("\n❌ Failed to send any notifications")
            return 1
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
