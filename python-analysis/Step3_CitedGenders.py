from pymongo import MongoClient
import pandas as pd

'''
Assigns the gender groups of the cited papers. 
Adds a new field with the updated information: 

Field guide:
AF=authors                          SO=journal              DT=article type             CR=reference list
TC=total citation                   PD=publication month    PY=publication year         DI=DOI
AG=first and last author gender     CP=cited papers         SA=papers w/ same author

CP_no_self = cited papers with self citations removed 
CP_gender = cited papers first and last author gender 
'''

MONGODB_URI = "mongodb://localhost:27017/"
DATABASE_NAME = "gender-citations-swe"
COLLECTION_NAME = "article-data"


def get_df(collection):
    data = list(collection.find({}, {"index": 1, "AG": 1, "_id": 0}))
    df = pd.DataFrame(data)
    return df


def import_db(collection, df):
    documents = collection.find()
    for doc in documents:
        print(doc.get('index'))
        cited_genders = []      # init an empty list to store cited paper genders

        refs = doc.get('CP_no_self')    # gets the list of cited papers
        # if no cited papers = empty list
        if refs == "":
            cited_genders = []
        else:
            # for each cited paper, match the index with the index in the dataframe to extract the gender information
            for ref in refs.split(', '):
                ref = int(ref)
                gender = df.loc[df['index'] == ref, 'AG'].values[0]
                cited_genders.append(gender)    # add this value to the list

        # update the database to include this new cited paper gender list
        collection.update_one(
            {"_id": doc["_id"]},
            {"$set": {"CP_gender": cited_genders}}
        )


if __name__ == "__main__":
    # connect to mongoDB
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    collection = db[COLLECTION_NAME]

    # create a dataframe with the gender data for each article in the database
    df = get_df(collection)
    # print(df)

    import_db(collection, df)


