from pymongo import MongoClient
import pandas as pd

'''
Removes self-citations from the cited-papers list in the mongoDB.
Adds a new field with the updated information: 

Field guide:
AF=authors                          SO=journal              DT=article type             CR=reference list
TC=total citation                   PD=publication month    PY=publication year         DI=DOI
AG=first and last author gender     CP=cited papers         SA=papers w/ same author

CP_no_self = cited papers with self citations removed 
'''

MONGODB_URI = "mongodb://localhost:27017/"
DATABASE_NAME = "gender-citations-swe"
COLLECTION_NAME = "article-data"


def get_df(collection):
    data = list(collection.find({}, {"CP": 1, "SA": 1, "index": 1, "_id": 0}))
    df = pd.DataFrame(data)
    return df


def get_overlap(cp, sa):
    if not cp or not sa:
        return []
    cp_numbers = set(map(int, cp.split(', '))) if cp else set()
    sa_numbers = set(map(int, sa.split(', '))) if sa else set()
    overlap = cp_numbers.intersection(sa_numbers)
    return list(overlap)


def remove_overlap(cp, overlap):
    if not cp:
        return ''
    cp_numbers = set(map(int, cp.split(', ')))
    remaining_numbers = cp_numbers - set(overlap)
    return ', '.join(map(str, remaining_numbers))


def import_db(collection, df):
    documents = collection.find()
    for doc in documents:
        index = doc.get('index')
        print(index)

        # if index in the result df = the cited papers included self-citations
        if index in df['index'].values:
            # update with the new self-citations removed
            cp_no_self = df.loc[result['index'] == index, 'CP_no_self'].values[0]
        else:
            # no self-citations, keep the cited papers as is
            cp_no_self = doc.get('CP')

        collection.update_one(
            {"_id": doc["_id"]},
            {"$set": {"CP_no_self": cp_no_self}}
        )


if __name__ == "__main__":
    # connect to mongoDB
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    collection = db[COLLECTION_NAME]

    # dataframe with only: CP = cited papers, SA = same author, index = paper ID
    df = get_df(collection)
    # print(df.head().to_string())

    # Adds list of any overlapping indices between CP and SA
    df['overlapping_numbers'] = df.apply(lambda row: get_overlap(row['CP'], row['SA']), axis=1)
    # Subtracts overlapping indices from CP list
    # This is equivalent to removing self-citations
    df['CP_no_self'] = df.apply(lambda row: remove_overlap(row['CP'], row['overlapping_numbers']), axis=1)

    # creates a subset of from df and includes only rows which had self-citations
    result = df[df['overlapping_numbers'].map(len) > 0]
    result = result.drop(columns=['CP', 'SA', 'overlapping_numbers'])

    # print(result.head().to_string())

    # updates the mongoDB and includes a new field; CP_no_self = cited papers with self-citations removed
    import_db(collection, result)





