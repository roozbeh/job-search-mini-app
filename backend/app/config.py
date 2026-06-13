from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # MongoDB
    mongodb_url: str = "mongodb://localhost:27017"
    mongodb_db: str = "jobsearch"

    # Job search provider
    job_search_provider: str = "serpapi"
    serpapi_key: str = ""
    agnic_job_search_base: str = "https://api.agnic.ai/v1/custom/job-search"
    agnic_fetch_proxy: str = "https://api.agnic.ai/api/x402/fetch"

    # Resume analysis (deep reasoning — called once per resume upload)
    resume_analysis_model: str = "openai/gpt-4o"
    resume_analysis_key: str = ""
    resume_analysis_url: str = "https://api.agnic.ai/v1"

    # Title expansion (creative diversity — two models in parallel, once per search)
    title_expansion_model_a: str = "openai/gpt-5"
    title_expansion_model_b: str = "anthropic/claude-sonnet-4"
    title_expansion_key: str = ""
    title_expansion_url: str = "https://api.agnic.ai/v1"

    # Match score (cheap, high-volume — called per job card)
    match_score_model: str = "openai/gpt-4o-mini"
    match_score_key: str = ""
    match_score_url: str = "https://api.agnic.ai/v1"

    # Legacy fallback key (user-pays Agnic token fallback when role keys absent)
    agnicpay_api_key: str = ""

    port: int = 8000

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
