import json
from pymongo import MongoClient
import os

'''
Inserts the exported json file from Part A (R-code) into a MongoDB

Field guide:
AF=authors                          SO=journal              DT=article type             CR=reference list
TC=total citation                   PD=publication month    PY=publication year         DI=DOI
AG=first and last author gender     CP=cited papers         SA=papers w/ same author
'''

# Replace the following with your MongoDB connection details
MONGODB_URI = "mongodb://localhost:27017/"
DATABASE_NAME = "gender-citations-swe"
COLLECTION_NAME = "article-data"


def import_json_to_mongodb(json_file, mongodb_uri, db_name, collection_name):
    client = MongoClient(mongodb_uri)
    db = client[db_name]
    collection = db[collection_name]

    # Load the JSON file
    with open(json_file, 'r') as file:
        data = json.load(file)

        # Ensure the data is a list of documents
        if isinstance(data, list):
            collection.insert_many(data)
        else:
            collection.insert_one(data)

    print(f"Data from {json_file} has been imported into the {collection_name} collection of {db_name} database.")


def change_year(mongodb_uri, db_name, collection_name):
    client = MongoClient(mongodb_uri)
    db = client[db_name]
    collection = db[collection_name]

    # Update records where PY is 2025 to 2024 (there are 2025 records because they are early access)
    collection.update_many(
        {'PY': 2025},
        {'$set': {'PY': 2024}}
    )


if __name__ == "__main__":
    # get the file path of the article_data.json file from the end of section A
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    fp = os.path.join(base_dir, 'R-processing', 'article_data.json')

    import_json_to_mongodb(fp, MONGODB_URI, DATABASE_NAME, COLLECTION_NAME)
    change_year(MONGODB_URI, DATABASE_NAME, COLLECTION_NAME)


