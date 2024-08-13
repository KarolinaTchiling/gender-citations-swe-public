from scipy.interpolate import make_interp_spline
import matplotlib.pyplot as plt
from pymongo import MongoClient
import pandas as pd
import numpy as np

'''
Creates the temporal plots which show the trends in authorship and citations 

Field guide:
AF=authors                          SO=journal              DT=article type             CR=reference list
TC=total citation                   PD=publication month    PY=publication year         DI=DOI
AG=first and last author gender     CP=cited papers         SA=papers w/ same author
CP_no_self = cited papers with self citations removed       CP_gender = cited papers first and last author gender  
'''

MONGODB_URI = "mongodb://localhost:27017/"
DATABASE_NAME = "gender-citations-swe"
COLLECTION_NAME = "article-data"


plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['axes.titlesize'] = 16
plt.rcParams['axes.labelsize'] = 10


def get_df(collection):
    data = list(collection.find({}, {"PY": 1, "CP_gender": 1, "AG": 1, "_id": 0}))
    df = pd.DataFrame(data)
    clean_df = df.loc[~df['AG'].isin(['UM', 'MU', 'UU', 'WU', 'UW'])].reset_index(drop=True)
    return clean_df


def print_counts(df):
    expected = calculate_proportions(df)
    expected_counts = expected.groupby('PY')['count'].sum().reset_index()
    expected_counts.rename(columns={'count': 'article-count'}, inplace=True)

    observed = calculate_cited_proportions(df)
    observed_counts = observed.groupby('PY')['count'].sum().reset_index()
    observed_counts.rename(columns={'count': 'citation-count'}, inplace=True)

    counts = pd.merge(expected_counts, observed_counts, on='PY')

    total_arts = counts['article-count'].sum()
    counts['proportion-ac'] = counts['article-count'] / total_arts * 100

    total_citations = counts['citation-count'].sum()
    counts['proportion-cc'] = counts['citation-count'] / total_citations * 100

    print(counts)
    print(f"\n Total articles: {total_arts}")
    print(f"Total citations: {total_citations}")


def calculate_cited_proportions(df):
    df = df.drop(columns=['AG'])
    year_list = [2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024]
    results = []

    for year in year_list:
        df_year = df[df['PY'] == year].reset_index(drop=True)
        # expand the cited gender categories
        flattened = df_year["CP_gender"].explode()
        cited_counts = {
            'MM': flattened.value_counts().get('MM', 0),
            'MW': flattened.value_counts().get('MW', 0),
            'WM': flattened.value_counts().get('WM', 0),
            'WW': flattened.value_counts().get('WW', 0)
        }
        cited_df = pd.DataFrame(list(cited_counts.items()), columns=['AG', 'count'])
        cited_df['proportion'] = (cited_df['count'] / cited_df['count'].sum()) * 100
        cited_df['PY'] = year
        results.append(cited_df)

    results_df = pd.concat(results).reset_index(drop=True)
    return results_df


def calculate_proportions(df):
    df = df.drop(columns=['CP_gender'])
    year_list = [2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024]
    results = []

    for year in year_list:
        df_year = df[df['PY'] == year].reset_index(drop=True)
        category_counts_df = df_year['AG'].value_counts().reset_index()
        category_counts_df.columns = ['AG', 'count']
        total_count = len(df_year)
        category_counts_df['proportion'] = (category_counts_df['count'] / total_count) * 100
        category_counts_df['PY'] = year
        results.append(category_counts_df)

    results_df = pd.concat(results).reset_index(drop=True)
    return results_df


def plot_proportions(df, title):
    if title == "Authorship":
        proportions_df = calculate_proportions(df)
    else:
        proportions_df = calculate_cited_proportions(df)

    print("First Year:")
    print(proportions_df.head(4))

    # Print the last 4 rows
    print("\nLast Year:")
    print(proportions_df.tail(4))

    # Pivot the DataFrame to have years as rows and categories as columns
    pivot_df = proportions_df.pivot(index='PY', columns='AG', values='proportion').fillna(0)

    custom_colors = ["#B64402", "#F58400", "#8182EF", "#3320DC"]
    desired_order = ["WW", "WM", "MW", "MM"]

    # Reorder the columns of the pivot_df and custom_colors list
    pivot_df = pivot_df[desired_order]
    pivot_df.rename(columns={'WW': 'Woman first author & woman last author',
                       'WM': 'Woman first author & man last author',
                       'MW': 'Man first author & woman last author',
                       'MM': 'Man first author & man last author'}, inplace=True)

    x_smooth = np.linspace(pivot_df.index.min(), pivot_df.index.max(), 300)
    pivot_smooth = pd.DataFrame({AG: make_interp_spline(pivot_df.index, pivot_df[AG])(x_smooth)
                                 for AG in pivot_df.columns})

    # Plot the stacked area chart with smoothing and custom colors
    fig, ax = plt.subplots(figsize=(11, 7))
    ax.stackplot(x_smooth,
                  pivot_smooth.values.T,
                  labels=pivot_smooth.columns,
                  colors=custom_colors,
                  alpha=0.8)

    cumulative = np.zeros_like(x_smooth)
    for i, category in enumerate(pivot_df.columns):
        ax.plot(x_smooth, cumulative, color='black', linewidth=0.5)  # Plot the cumulative boundary
        cumulative += pivot_smooth[category]

    # Remove the white border by setting x-axis and y-axis limits
    ax.set_xlim(2009, 2024)
    ax.set_ylim(0, 100)

    # Set labels and title
    ax.set_xlabel('Year')
    if title == "Authorship":
        ax.set_ylabel('Proportion of Papers (%)')
        ax.set_title(f'Trends in Authorship - Expected Proportion')
    else:
        ax.set_ylabel('Proportion of Citations (%)')
        ax.set_title(f'Trends in Citations - Observed Proportion')
    ax.set_ylim(0, 100)

    # Add detailed grid lines
    ax.grid(True, which='major', linestyle='--', linewidth=0.5, alpha=0.8, color='grey')  # Major grid lines
    ax.minorticks_on()  # Enable minor ticks
    ax.grid(which='minor', linestyle=':', linewidth=0.5, alpha=0.3)  # Minor grid lines

    # Customize the legend
    handles, labels = ax.get_legend_handles_labels()
    legend = plt.legend(handles[::-1], labels[::-1], loc='upper right',  fontsize='medium', title_fontsize='large', frameon=True)

    # Customize the legend border and background
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    legend.get_frame().set_facecolor('white')

    # Add black border around the color boxes in the legend
    for patch in legend.get_patches():
        patch.set_edgecolor('black')
        patch.set_linewidth(0.8)

    plt.xticks(ticks=np.arange(pivot_df.index.min(), pivot_df.index.max() + 1, 5))

    # Annotations for the values per category ----------------------------------------------------------
    # HARDCODED SECTION
    def add_annotation(value_placement, amount, color, x):
        plt.text(x, value_placement, f'~{amount}%', fontsize=10, color=color, fontweight='bold')

    if title == "Authorship":
        # right side labels
        values_placement = [2, 15, 27, 40]        # change placement on plot
        amounts = [5.5, 18.2, 10.3, 66.0]           # change values
        for value, amount, color in zip(values_placement, amounts, custom_colors):
            add_annotation(value, amount, color, 2024.1)
        # left side labels
        values_placement = [1, 7, 18, 27]
        amounts = [3.2, 10.4, 9.0, 77.4]
        for value, amount, color in zip(values_placement, amounts, custom_colors):
            add_annotation(value, amount, color, 2007.5)
    else:
        # right side labels
        values_placement = [1, 10, 22, 32]
        amounts = [4.3, 14.1, 9.5, 72.1]
        for value, amount, color in zip(values_placement, amounts, custom_colors):
            add_annotation(value, amount, color, 2024.1)
        # left side labels
        values_placement = [0.5, 7, 16, 25]
        amounts = [3.3, 9.3, 7.5, 79.9]
        for value, amount, color in zip(values_placement, amounts, custom_colors):
            add_annotation(value, amount, color, 2007.5)

    # plt.show()


if __name__ == "__main__":
    # connect to mongoDB
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    collection = db[COLLECTION_NAME]

    # create a dataframe with the author gender and cited paper genders for each article
    df = get_df(collection)
    print_counts(df)      # see count stats on data

    # create a subset of the data from 2009
    df_2009 = df[df['PY'].isin([2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024])]

    '''
    IMPORTANT NOTE: the annotations on the side of plots are hard coded, you must change them based on the
    the console out proportions. Change them in the plot_proportions function -> annotations section -> amounts
    '''
    plot_proportions(df_2009, 'Authorship')  # plot the proportion of author genders through time
    plt.savefig('temporal_figures/authorship_trends.png',  dpi=800)
    plot_proportions(df_2009, 'Citations')   # plot the proportion of cited author genders through time
    plt.savefig('temporal_figures/citation_trends.png',  dpi=800)

