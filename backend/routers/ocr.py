from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from deps import get_current_user
from services.llm_service import LLMService

router = APIRouter()
_llm = LLMService()


class OcrIn(BaseModel):
    image: str  # base64


class OcrOut(BaseModel):
    text: str


@router.post("/image", response_model=OcrOut)
def recognize(body: OcrIn, user=Depends(get_current_user)):
    if not body.image:
        raise HTTPException(400, "image 不能为空")
    try:
        text = _llm.chat_with_vision(
            messages=[{"role": "system", "content": "请识别图片中的文字内容，只输出文字，不要其他说明。"}],
            image_b64=body.image,
        )
        return OcrOut(text=text)
    except Exception as e:
        raise HTTPException(500, f"OCR 识别失败：{e}")
