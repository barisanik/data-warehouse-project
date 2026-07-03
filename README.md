# Veri Ambarı Projesi
(TR 🇹🇷 | [English below](#data-warehouse-project))

Bu proje; SQL Server üzerinde çalışan, analiz süreçleri için tasarlanmış uçtan uca bir veri ambarı (Data Warehouse) oluşturma sürecini ve buna ait SQL sorgularını içermektedir.

## Kullanılan Teknolojiler (Main Branch > Cloud)

| Katman | Teknoloji |
|--------|-----------|
| Veritabanı | BigQuery (Google) |
| Veri Çekme | Python ([get_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/get_data.py) & [load_bronze_csv_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/load_bronze_csv_data.py)) |
| Simülasyon | Python ([simulate_ship_date.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/simulate_ship_date.py)) |
| Dönüşüm | dbt Cloud (Silver + Gold katmanları)|
| Test | pytest & dbt Cloud |
| Kod Kalitesi ve Güvenlik | Sonar Cloud |
| Orkestrasyon | GitHub Actions [ci.yml](https://github.com/barisanik/data-warehouse-project/blob/main/.github/workflows/ci.yml) |
| Raporlama | Data Studio (Google) |

## Kullanılan Teknolojiler (v1 Branch > Local)

| Katman | Teknoloji |
|--------|-----------|
| Veritabanı | SQL Server |
| Veri Çekme | Python ([get_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/get_data.py) & [load_bronze_csv_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/load_bronze_csv_data.py)) |
| Simülasyon | Python ([simulate_ship_date.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/simulate_ship_date.py)) |
| Dönüşüm | dbt Core (Silver + Gold katmanları)|
| Test | pytest & dbt Core |
| Orkestrasyon | Apache Airflow |
| Container | Docker + Docker Compose |
| Raporlama | Metabase |

## Mimari

<img width="8477" height="2762" alt="data-architecture-diagram" src="https://github.com/user-attachments/assets/1ea96314-d739-4e6d-b558-d06167fe8011" />

## Pipeline Akışı

```
ingestion → simulation → dbt run → dbt test
```

## Veri Kaynağı

Projede kullanılan CSV dosyaları [datasets](https://github.com/barisanik/data-warehouse-project/tree/main/datasets) dizini altında yer almaktadır.
Kullanılan API adresleri:
- [Dummy JSON - Products](https://dummyjson.com/products?limit=1000)
- [Dummy JSON - Users](https://dummyjson.com/user?limit=10000)
- [Dummy JSON - Carts](https://dummyjson.com/carts?limit=10000)
<img width="10112" height="6096" alt="ER Diagram" src="https://github.com/user-attachments/assets/e7c01ed7-526c-4a9f-af03-64470fd8a24e" />

## Kurulum
**Gereksinimler:** Google Cloud Platform, dbt Cloud

1. Repo'yu klonlayın.
2. Projenin ana dizininde `.env` dosyasını oluşturun:
.env dosyası örneği için [.env - Sample](https://github.com/barisanik/data-warehouse-project/blob/main/.env%20-%20Sample) dosyasına göz atabilirsiniz.
3. GitHub repository ayarları > Secrets and Variables > Actions sekmesinden gerekli değişkenleri tanımlayın:
   - DBT_ACCOUNT_ID
   - DBT_ACCESS_URL
   - DBT_API_TOKEN
   - DBT_CI_PASSWORD
   - DBT_JOB_ID
   - GCP_PROJECT_ID
   - GCP_SA_KEY

## Proje Kararları

- Mimari
  - Veri modelleme aşaması için madalyon mimarisi (bronze-silver-gold) kullanılacaktır.
  - CSV ve API kaynaklarından gelen kayıtlar UNION ALL ile birleştirildiğinde ID çakışmasını önlemek amacıyla kaynak bazlı prefix stratejisi uygulanmıştır. CSV kaynaklı kayıtlar `CSV-`, API kaynaklı kayıtlar `API-` prefix'i ile işaretlenir.
- Veri çekme
  - Veri çekme aşamasında %40 oranında kasıtlı veri bozulması uygulanır. Bu sayede bozuk veri kalitesi durumları simüle edilir.
  - Veri yükleme tekniği olarak Full Load tercih edilmiştir. Veri kaynağından veri ambarına tüm veriler tek seferde aktarılacaktır.
  - Dummyjson kaynağından elde edilen sepetteki ürün verileri veri ambarına sipariş olarak işlenecektir.
- Dönüşüm
  - İkame edilemeyen tüm NULL değerler 'n/a' olarak düzenlenecektir.
  - Doğru olmayan doğum tarihleri (çok eski veya 18 yaşından genç olan) NULL olarak kaydedilecektir.
  - Sembol ve kısaltma olarak kullanılan tüm ifadeler anlamlı metinlerle değiştirilecektir.
- Sözdizimi
  - Değişken isimlendirme metodu olarak snake case kullanılacaktır.
  - Sorgularda ve kod parçacıklarında yorum satırlarında İngilizce dili kullanılacaktır.
- Kullanılan teknolojiler
  - dbt veri kalite kontrolü, silver ve gold katman tablolarının oluşturulmasında kullanılacaktır. Bronze katman tablolarında ham veri tutulması nedeniyle veri kalite kontrolü uygulanmayacaktır.

## Referanslar
Bu proje aşağıdaki kaynağı referans alarak oluşturulmuştur. Temel metodoloji ilgili videoya dayanmakla birlikte farklı veri kaynakları projeye entegre edilerek modelleme süreçleri bu doğrultuda genişletilmiştir.
- [SQL Data Warehouse from Scratch - Data with Baraa](https://youtu.be/9GVqKuTVANE?si=pPUQ8cy8OA3J2cBF)

---

# Data Warehouse Project
(EN 🇬🇧)

This project showcases an end-to-end data warehousing and analytics solution. It includes SQL scripts for building a data warehouse for analytical purposes on SQL Server.

## Tech Stack (Main Branch > Cloud)

| Layer | Technology |
|--------|-----------|
| Database | BigQuery (Google) |
| Ingestion | Python ([get_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/get_data.py) & [load_bronze_csv_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/load_bronze_csv_data.py)) |
| Simulation | Python ([simulate_ship_date.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/simulate_ship_date.py)) |
| Transformation | dbt Cloud (Silver + Gold layers)|
| Test | pytest & dbt Cloud |
| Code Quality and Security | Sonar Cloud |
| Orchestration | GitHub Actions [ci.yml](https://github.com/barisanik/data-warehouse-project/blob/main/.github/workflows/ci.yml) |
| Reporting | Data Studio (Google) |

## Tech Stack (v1 Branch > Local)

| Layer | Technology |
|--------|-----------|
| Database | SQL Server |
| Ingestion | Python ([get_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/get_data.py) & [load_bronze_csv_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/load_bronze_csv_data.py)) |
| Simulation | Python ([simulate_ship_date.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/simulate_ship_date.py)) |
| Transformation | dbt Core (Silver + Gold layers)|
| Test | pytest & dbt Core |
| Orchestration | Apache Airflow |
| Container | Docker + Docker Compose |
| Reporting | Metabase |

## Architecture

<img width="8477" height="2762" alt="data-architecture-diagram" src="https://github.com/user-attachments/assets/1ea96314-d739-4e6d-b558-d06167fe8011" />

## Pipeline Flow

```
ingestion → simulation → dbt run → dbt test
```

## Data Source

CSV files used in this project can be found under the [datasets](https://github.com/barisanik/data-warehouse-project/tree/main/datasets) directory.
API endpoints used:
- [Dummy JSON - Products](https://dummyjson.com/products?limit=1000)
- [Dummy JSON - Users](https://dummyjson.com/user?limit=10000)
- [Dummy JSON - Carts](https://dummyjson.com/carts?limit=10000)
<img width="10112" height="6096" alt="ER Diagram" src="https://github.com/user-attachments/assets/e7c01ed7-526c-4a9f-af03-64470fd8a24e" />

## Initialization
**Requirements:** Google Cloud Platform, dbt Cloud

1. Clone this repo.
2. Create a `.env` file in the project root:
3. Define repository secrets via GitHub repository settings > Secrets and Variables > Actions:
   - DBT_ACCOUNT_ID
   - DBT_ACCESS_URL
   - DBT_API_TOKEN
   - DBT_CI_PASSWORD
   - DBT_JOB_ID
   - GCP_PROJECT_ID
   - GCP_SA_KEY

## Project Decisions

- Architecture
  - The medallion architecture (bronze-silver-gold) will be utilized for the data modeling phase.
  - A source-based prefix strategy is applied to prevent ID collisions when combining CSV and API records with UNION ALL. CSV-sourced records are prefixed with `CSV-`, API-sourced records with `API-`.
- Ingestion
  - Approximately 40% of ingested API records are intentionally corrupted to simulate real-world data quality issues.
  - Full load has been preferred as the data loading technique, meaning the entire dataset from the source files will be transferred to the data warehouse in a single operation.
  - Cart data sourced from DummyJSON is processed as orders.
- Transformation
  - All non-replaceable NULL values will be set to 'n/a'.
  - Unrealistic or invalid birth dates (e.g., unrealistically old or under 18) are replaced with NULL
  - All symbols and abbreviations will be replaced with meaningful descriptions.
- Syntax
  - Snake case will be used for variable naming.
  - English will be used in comments for queries and code snippets.
- Tech Stack
  - dbt will be utilized for data quality control, as well as the creation of silver layer tables and gold layer tables. Data quality control will not be applied to bronze layer tables, as they store raw data.

## References

This project was built using the following video resource. Although the foundational methodology relies on the video, the data modeling processes were expanded by integrating diverse data sources.
- [SQL Data Warehouse from Scratch - Data with Baraa](https://youtu.be/9GVqKuTVANE?si=pPUQ8cy8OA3J2cBF)

---

# Kod Kalite Analizi Sonuçları / Code Quality Analysis Results

[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=barisanik_data-warehouse-project&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=barisanik_data-warehouse-project)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=barisanik_data-warehouse-project&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=barisanik_data-warehouse-project)
[![Technical Debt](https://sonarcloud.io/api/project_badges/measure?project=barisanik_data-warehouse-project&metric=sqale_index)](https://sonarcloud.io/summary/new_code?id=barisanik_data-warehouse-project)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=barisanik_data-warehouse-project&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=barisanik_data-warehouse-project)
[![Vulnerabilities](https://sonarcloud.io/api/project_badges/measure?project=barisanik_data-warehouse-project&metric=vulnerabilities)](https://sonarcloud.io/summary/new_code?id=barisanik_data-warehouse-project)

[![SonarQube Cloud](https://sonarcloud.io/images/project_badges/sonarcloud-highlight.svg)](https://sonarcloud.io/summary/new_code?id=barisanik_data-warehouse-project)
