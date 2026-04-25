import re
with open('backend/database.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()
keywords = ['class MindmapNodeState', 'class Subject(Base', 'class StudyPlan', 'class PlanItem', 'class FeedbackSignal']
for i, l in enumerate(lines):
    for kw in keywords:
        if kw in l:
            print(f'{i+1}: {l}', end='')
            break