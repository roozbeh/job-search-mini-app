from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    mongodb_url: str = "mongodb://localhost:27017"
    mongodb_db: str = "jobsearch"

    agnic_llm_base: str = "https://api.agnic.ai/v1"
    agnic_job_search_base: str = "https://api.agnic.ai/v1/custom/job-search"
    agnic_fetch_proxy: str = "https://api.agnic.ai/api/x402/fetch"

    port: int = 8000

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
