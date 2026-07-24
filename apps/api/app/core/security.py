from secrets import compare_digest
from typing import Annotated, Callable

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer


_bearer = HTTPBearer(auto_error=False)


def build_token_guard(access_token: str) -> Callable[..., None]:
    def require_token(
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    ) -> None:
        if not access_token:
            return
        if credentials is None or not compare_digest(
            credentials.credentials, access_token
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="访问令牌无效",
                headers={"WWW-Authenticate": "Bearer"},
            )

    return require_token
