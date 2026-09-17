import pandas as pd

df = pd.read_csv("../Data/olist_order_reviews_dataset.csv", encoding="utf-8")

df["review_comment_message"] = df["review_comment_message"].str.replace("\n", " ", regex=False).str.replace('\r', " ", regex=False)
df["review_comment_title"] = df["review_comment_title"].str.replace("\n", " ", regex=False).str.replace('\r', " ", regex=False)

df["review_comment_title"] = df["review_comment_title"].fillna("No Title")
df["review_comment_message"] = df["review_comment_message"].fillna("No Comment")

df["review_comment_message"] = df["review_comment_message"].str.replace('"', ' ', regex=False).str.replace('\\', ' ', regex=False)
df["review_comment_title"] = df["review_comment_title"].str.replace('"', ' ', regex=False).str.replace('\\', ' ', regex=False)


df.to_csv("../Data/Clean_Data/olist_order_reviews_dataset_celan.csv", index=False)
