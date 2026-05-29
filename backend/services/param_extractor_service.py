"""
参数提取服务 - 语义日期解析和学科标准化
"""
from __future__ import annotations

import re
from datetime import date, datetime, timedelta
from typing import Optional

from cas.models import PlanningParams


class ParamExtractorService:
    """参数提取服务"""
    
    # 语义日期映射（相对当前日期的天数）
    DATE_PATTERNS: dict[str, int] = {
        '本周': 0,      # 本周末
        '下周': 7,
        '下下周': 14,
        '下个月': 30,
        '期末': -1,     # 特殊标记，需要根据当前月份计算
        '期中': -2,     # 特殊标记
        '中考': -3,     # 特殊标记
        '高考': -4,     # 特殊标记
    }
    
    # 学科关键词映射
    SUBJECT_KEYWORDS: dict[str, str] = {
        '数学': 'math',
        '语文': 'chinese',
        '英语': 'english',
        '物理': 'physics',
        '化学': 'chemistry',
        '生物': 'biology',
        '历史': 'history',
        '地理': 'geography',
        '政治': 'politics',
        '奥数': 'olympiad_math',
    }
    
    async def extract_params(self, text: str) -> PlanningParams:
        """从文本中提取所有参数"""
        params = PlanningParams()
        
        # 提取学科
        subject_id = await self.normalize_subject(text)
        if subject_id:
            params.subject_id = subject_id
            # 从文本中提取学科名称
            for name, sid in self.SUBJECT_KEYWORDS.items():
                if name in text:
                    params.subject_name = name
                    break
        
        # 提取日期
        exam_date = await self.parse_date(text)
        if exam_date:
            params.exam_date = exam_date
        
        # 提取考试范围
        params.exam_scope = self._extract_scope(text)
        
        # 提取每日学习时长
        params.daily_hours = self._extract_daily_hours(text)
        
        # 提取目标分数
        params.target_score = self._extract_target_score(text)
        
        # 检查参数完整性
        params.is_complete = self._check_completeness(params)
        params.missing_params = self._get_missing_params(params)
        
        return params
    
    async def parse_date(self, date_str: str) -> Optional[date]:
        """语义日期解析："下个月期末" → 具体日期"""
        now = datetime.now()
        
        # 先检查精确日期匹配
        # 匹配"X月Y日"格式
        month_day_match = re.search(r'(\d{1,2})月(\d{1,2})日?', date_str)
        if month_day_match:
            month = int(month_day_match.group(1))
            day = int(month_day_match.group(2))
            year = now.year if month >= now.month else now.year + 1
            return date(year, month, day)
        
        # 匹配"X-Y"格式
        dash_match = re.search(r'(\d{1,2})-(\d{1,2})', date_str)
        if dash_match:
            month = int(dash_match.group(1))
            day = int(dash_match.group(2))
            year = now.year if month >= now.month else now.year + 1
            return date(year, month, day)
        
        # 匹配"本周"
        if '本周' in date_str:
            days_until_saturday = 5 - now.weekday()  # 假设周六为周末
            if days_until_saturday <= 0:
                days_until_saturday += 7
            return (now + timedelta(days=days_until_saturday)).date()
        
        # 匹配"下周"
        if '下周' in date_str:
            return (now + timedelta(days=7)).date()
        
        # 匹配"下下周"
        if '下下周' in date_str:
            return (now + timedelta(days=14)).date()
        
        # 匹配"下个月"
        if '下个月' in date_str:
            if now.month == 12:
                return date(now.year + 1, 1, 15)
            else:
                return date(now.year, now.month + 1, 15)
        
        # 匹配"期末"
        if '期末' in date_str:
            # 假设期末是6月中旬或1月中旬
            if now.month <= 6:
                return date(now.year, 6, 15)
            else:
                return date(now.year + 1, 1, 15)
        
        # 匹配"期中"
        if '期中' in date_str:
            if now.month <= 4:
                return date(now.year, 4, 15)
            elif now.month <= 10:
                return date(now.year, 10, 15)
            else:
                return date(now.year + 1, 4, 15)
        
        # 匹配"中考" - 假设是每年6月
        if '中考' in date_str:
            return date(now.year, 6, 15)
        
        # 匹配"高考" - 假设是每年6月7日
        if '高考' in date_str:
            return date(now.year, 6, 7)
        
        return None
    
    async def normalize_subject(self, subject_name: str) -> Optional[int]:
        """学科标准化：匹配已有学科ID"""
        # 从数据库获取学科列表进行匹配
        # 这里先返回简单的映射，后续可以从数据库查询
        
        for name, sid in self.SUBJECT_KEYWORDS.items():
            if name in subject_name:
                # 返回学科ID（这里返回0表示需要后续从数据库查询）
                # 实际使用时应该从数据库查询真实ID
                return 0
        
        return None
    
    def _extract_scope(self, text: str) -> Optional[str]:
        """提取考试范围"""
        # 匹配"前X章"
        scope_match = re.search(r'前(\d+)章', text)
        if scope_match:
            return f"前{scope_match.group(1)}章"
        
        # 匹配"第X章到第Y章"
        range_match = re.search(r'第(\d+)章到第(\d+)章', text)
        if range_match:
            return f"第{range_match.group(1)}章到第{range_match.group(2)}章"
        
        # 匹配"全书"或"全部"
        if '全书' in text or '全部' in text:
            return '全书'
        
        # 匹配"上半学期"或"下半学期"
        if '上半' in text:
            return '上半学期'
        if '下半' in text:
            return '下半学期'
        
        return None
    
    def _extract_daily_hours(self, text: str) -> float:
        """提取每日学习时长"""
        # 匹配"每天X小时"
        hours_match = re.search(r'每天(\d+\.?\d*)小时', text)
        if hours_match:
            return float(hours_match.group(1))
        
        # 匹配"每天X小时Y分钟"
        hours_minutes_match = re.search(r'每天(\d+)小时(\d+)分钟', text)
        if hours_minutes_match:
            hours = int(hours_minutes_match.group(1))
            minutes = int(hours_minutes_match.group(2))
            return hours + minutes / 60.0
        
        # 匹配"每天X分钟"
        minutes_match = re.search(r'每天(\d+)分钟', text)
        if minutes_match:
            return int(minutes_match.group(1)) / 60.0
        
        # 默认每天2小时
        return 2.0
    
    def _extract_target_score(self, text: str) -> Optional[int]:
        """提取目标分数"""
        # 匹配"X分"（2-3位数字）
        score_match = re.search(r'(\d{2,3})分', text)
        if score_match:
            score = int(score_match.group(1))
            # 验证分数范围合理
            if 0 <= score <= 100:
                return score
        
        # 匹配"考X分"
        target_match = re.search(r'考(\d{2,3})分', text)
        if target_match:
            return int(target_match.group(1))
        
        return None
    
    def _check_completeness(self, params: PlanningParams) -> bool:
        """检查参数是否完整"""
        # 至少需要学科和考试日期
        return params.subject_name is not None and params.exam_date is not None
    
    def _get_missing_params(self, params: PlanningParams) -> list:
        """获取缺失的必要参数"""
        missing = []
        
        if not params.subject_name:
            missing.append('subject')
        
        if not params.exam_date:
            missing.append('exam_date')
        
        if not params.exam_scope:
            missing.append('exam_scope')
        
        return missing
    
    async def get_param_options(self, param_name: str) -> list[str]:
        """获取参数选项（用于前端快捷输入）"""
        options_map = {
            'exam_date': ['本周', '下周', '下个月', '期末', '期中'],
            'exam_scope': ['全书', '前五章', '前十章', '指定章节'],
            'daily_hours': ['1小时', '2小时', '3小时', '4小时'],
            'target_score': ['60分', '70分', '80分', '90分', '100分'],
        }
        
        return options_map.get(param_name, [])