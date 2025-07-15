#!/usr/bin/env python3
"""
Create Jira tickets for critical blockers found in agent status report
"""

import os
import sys
import json
import requests
from datetime import datetime
from pathlib import Path
from requests.auth import HTTPBasicAuth

# Configuration
JIRA_URL = os.environ.get('JIRA_URL', 'https://zippycoin.atlassian.net')
JIRA_PROJECT_KEY = os.environ.get('JIRA_PROJECT_KEY', 'ZCAI')
JIRA_EMAIL = os.environ.get('JIRA_EMAIL', '{{JIRA_EMAIL}}')
JIRA_API_TOKEN = os.environ.get('JIRA_API_TOKEN', '{{JIRA_API_TOKEN}}')
JIRA_ASSIGNEE = os.environ.get('JIRA_ASSIGNEE', 'default')

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

def extract_critical_issues(report_content):
    """Extract critical issues from the report"""
    lines = report_content.split('\n')
    critical_issues = []
    
    # Find the critical issues section
    in_critical_section = False
    for i, line in enumerate(lines):
        if '## Critical Issues Summary' in line:
            in_critical_section = True
            continue
        
        if in_critical_section and line.startswith('## '):
            break
            
        if in_critical_section and line.strip() and not line.startswith('#'):
            # Parse critical issue line
            if line.strip().startswith(('1.', '2.', '3.')):
                parts = line.split(' - ', 1)
                if len(parts) == 2:
                    agent_info = parts[0].split('**')[1]
                    issue_desc = parts[1]
                    
                    # Extract agent ID and name
                    agent_id = agent_info.split()[0]
                    agent_name = agent_info.split('(')[1].rstrip(')')
                    
                    critical_issues.append({
                        'agent_id': agent_id,
                        'agent_name': agent_name,
                        'description': issue_desc
                    })
    
    # Also look for specific critical agents in the detailed section
    in_agent_section = False
    current_agent = None
    
    for line in lines:
        if line.startswith('### AGT-'):
            current_agent = {
                'id': line.split(':')[0].replace('### ', ''),
                'name': line.split(':')[1].strip()
            }
            in_agent_section = True
            continue
        
        if in_agent_section and '**Status**:' in line and 'Critical' in line:
            # This is a critical agent
            # Look for failures in the next few lines
            agent_index = lines.index(line)
            failures = []
            
            for j in range(agent_index, min(agent_index + 20, len(lines))):
                if '#### Failures:' in lines[j]:
                    # Collect failure lines
                    k = j + 1
                    while k < len(lines) and lines[k].startswith('-'):
                        failures.append(lines[k][2:])  # Remove the '- ' prefix
                        k += 1
                    break
            
            if failures and current_agent:
                # Check if we already have this issue
                existing = False
                for issue in critical_issues:
                    if issue['agent_id'] == current_agent['id']:
                        existing = True
                        break
                
                if not existing:
                    critical_issues.append({
                        'agent_id': current_agent['id'],
                        'agent_name': current_agent['name'],
                        'description': 'Multiple critical failures',
                        'failures': failures
                    })
    
    return critical_issues

def check_existing_ticket(agent_id, auth):
    """Check if a ticket already exists for this agent"""
    if JIRA_EMAIL == '{{JIRA_EMAIL}}' or JIRA_API_TOKEN == '{{JIRA_API_TOKEN}}':
        return None
    
    # Search for existing tickets
    jql = f'project = {JIRA_PROJECT_KEY} AND summary ~ "{agent_id}" AND status != Done'
    
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.get(
            f'{JIRA_URL}/rest/api/3/search',
            headers=headers,
            auth=auth,
            params={'jql': jql}
        )
        response.raise_for_status()
        
        results = response.json()
        if results['total'] > 0:
            return results['issues'][0]['key']
        
    except Exception as e:
        print(f"Error checking existing tickets: {e}")
    
    return None

def create_jira_ticket(issue, report_date):
    """Create a Jira ticket for a critical issue"""
    if JIRA_EMAIL == '{{JIRA_EMAIL}}' or JIRA_API_TOKEN == '{{JIRA_API_TOKEN}}':
        print("Jira credentials not configured. Skipping ticket creation.")
        return None
    
    auth = HTTPBasicAuth(JIRA_EMAIL, JIRA_API_TOKEN)
    
    # Check if ticket already exists
    existing_ticket = check_existing_ticket(issue['agent_id'], auth)
    if existing_ticket:
        print(f"ℹ️  Ticket already exists for {issue['agent_id']}: {existing_ticket}")
        return existing_ticket
    
    # Prepare ticket data
    summary = f"{issue['agent_id']}: {issue['agent_name']} - Critical Issue"
    
    description = {
        "type": "doc",
        "version": 1,
        "content": [
            {
                "type": "heading",
                "attrs": {"level": 3},
                "content": [{"type": "text", "text": "Critical Issue Detected"}]
            },
            {
                "type": "paragraph",
                "content": [
                    {"type": "text", "text": f"Agent ID: ", "marks": [{"type": "strong"}]},
                    {"type": "text", "text": issue['agent_id']}
                ]
            },
            {
                "type": "paragraph",
                "content": [
                    {"type": "text", "text": f"Agent Name: ", "marks": [{"type": "strong"}]},
                    {"type": "text", "text": issue['agent_name']}
                ]
            },
            {
                "type": "paragraph",
                "content": [
                    {"type": "text", "text": f"Issue: ", "marks": [{"type": "strong"}]},
                    {"type": "text", "text": issue['description']}
                ]
            },
            {
                "type": "paragraph",
                "content": [
                    {"type": "text", "text": f"Report Date: ", "marks": [{"type": "strong"}]},
                    {"type": "text", "text": report_date}
                ]
            }
        ]
    }
    
    # Add failures if available
    if 'failures' in issue and issue['failures']:
        description['content'].append({
            "type": "heading",
            "attrs": {"level": 4},
            "content": [{"type": "text", "text": "Specific Failures"}]
        })
        
        failure_list = {
            "type": "bulletList",
            "content": []
        }
        
        for failure in issue['failures']:
            failure_list['content'].append({
                "type": "listItem",
                "content": [{
                    "type": "paragraph",
                    "content": [{"type": "text", "text": failure}]
                }]
            })
        
        description['content'].append(failure_list)
    
    # Add next steps
    description['content'].extend([
        {
            "type": "heading",
            "attrs": {"level": 4},
            "content": [{"type": "text", "text": "Recommended Actions"}]
        },
        {
            "type": "orderedList",
            "content": [
                {
                    "type": "listItem",
                    "content": [{
                        "type": "paragraph",
                        "content": [{"type": "text", "text": "Investigate root cause of the issue"}]
                    }]
                },
                {
                    "type": "listItem",
                    "content": [{
                        "type": "paragraph",
                        "content": [{"type": "text", "text": "Implement fix or workaround"}]
                    }]
                },
                {
                    "type": "listItem",
                    "content": [{
                        "type": "paragraph",
                        "content": [{"type": "text", "text": "Test and verify resolution"}]
                    }]
                },
                {
                    "type": "listItem",
                    "content": [{
                        "type": "paragraph",
                        "content": [{"type": "text", "text": "Update monitoring to prevent recurrence"}]
                    }]
                }
            ]
        }
    ])
    
    # Create ticket payload
    payload = {
        "fields": {
            "project": {
                "key": JIRA_PROJECT_KEY
            },
            "summary": summary,
            "description": description,
            "issuetype": {
                "name": "Bug"
            },
            "priority": {
                "name": "Critical"
            },
            "labels": ["agent-monitor", "critical-issue", issue['agent_id']]
        }
    }
    
    # Add assignee if configured
    if JIRA_ASSIGNEE != 'default':
        payload['fields']['assignee'] = {"accountId": JIRA_ASSIGNEE}
    
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.post(
            f'{JIRA_URL}/rest/api/3/issue',
            headers=headers,
            auth=auth,
            data=json.dumps(payload)
        )
        response.raise_for_status()
        
        result = response.json()
        ticket_key = result['key']
        ticket_url = f"{JIRA_URL}/browse/{ticket_key}"
        
        print(f"✅ Created Jira ticket: {ticket_key} - {ticket_url}")
        return ticket_key
        
    except Exception as e:
        print(f"❌ Failed to create Jira ticket: {e}")
        if hasattr(e, 'response') and e.response:
            print(f"Response: {e.response.text}")
        return None

def main():
    """Main function"""
    try:
        # Read latest report
        report_name, report_content = read_latest_report()
        report_date = report_name.replace('agent_status_', '').replace('.md', '')
        
        print(f"📄 Processing report: {report_name}")
        
        # Extract critical issues
        critical_issues = extract_critical_issues(report_content)
        
        if not critical_issues:
            print("✅ No critical issues found!")
            return 0
        
        print(f"\n🚨 Found {len(critical_issues)} critical issue(s)")
        
        # Create Jira tickets
        created_tickets = []
        for issue in critical_issues:
            print(f"\nProcessing: {issue['agent_id']} - {issue['agent_name']}")
            ticket = create_jira_ticket(issue, report_date)
            if ticket:
                created_tickets.append(ticket)
        
        print(f"\n📋 Summary: Created {len(created_tickets)} Jira ticket(s)")
        
        # Save ticket references
        if created_tickets:
            tickets_file = Path('../reports/jira_tickets.json')
            existing_tickets = {}
            
            if tickets_file.exists():
                with open(tickets_file, 'r') as f:
                    existing_tickets = json.load(f)
            
            existing_tickets[report_date] = {
                'report': report_name,
                'tickets': created_tickets,
                'timestamp': datetime.now().isoformat()
            }
            
            with open(tickets_file, 'w') as f:
                json.dump(existing_tickets, f, indent=2)
        
        return 0
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
