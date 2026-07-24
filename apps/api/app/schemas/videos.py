from pydantic import BaseModel, Field
from typing import Optional, List, Dict


class Episode(BaseModel):
    name: str = Field(..., description="单集名称")
    url: str = Field(..., description="播放链接或需要解析的ID")


class VideoSimple(BaseModel):
    id: str = Field(..., description="视频ID")
    source_id: int = Field(..., description="影视源ID")
    source_name: str = Field(..., description="影视源名称")
    title: str = Field(..., description="视频标题")
    cover: Optional[str] = Field(None, description="海报图")
    category: Optional[str] = Field(None, description="分类")
    remarks: Optional[str] = Field(None, description="备注，如更新至几集、高清")


class VideoDetail(BaseModel):
    id: str = Field(..., description="视频ID")
    source_id: int = Field(..., description="影视源ID")
    source_name: str = Field(..., description="影视源名称")
    title: str = Field(..., description="视频标题")
    cover: Optional[str] = Field(None, description="海报图")
    category: Optional[str] = Field(None, description="分类")
    remarks: Optional[str] = Field(None, description="备注")
    director: Optional[str] = Field(None, description="导演")
    actor: Optional[str] = Field(None, description="演员")
    description: Optional[str] = Field(None, description="简介")
    area: Optional[str] = Field(None, description="地区")
    year: Optional[str] = Field(None, description="年份")
    last_update: Optional[str] = Field(None, description="更新时间")
    playlists: Dict[str, List[Episode]] = Field(
        default_factory=dict, description="播放源线路及剧集列表"
    )


class ParseResult(BaseModel):
    url: str = Field(..., description="解析后的播放直链 (mp4, m3u8)")
    headers: Optional[Dict[str, str]] = Field(
        None, description="播放所需的Headers(防盗链等)"
    )
    parse_type: str = Field("direct", description="直链 direct 还是通过后台代理 proxy")
    proxy_url: Optional[str] = Field(
        None, description="客户端直连失败时使用的云端代理地址"
    )
    resolved: bool = Field(False, description="原始地址是否经过网页解析")
