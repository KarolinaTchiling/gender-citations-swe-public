from pymongo import MongoClient
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys

'''
Computes the Gender Citation Balance Index, bootstraps and plots the results as they change through time.
'''

MONGODB_URI = "mongodb://localhost:27017/"
DATABASE_NAME = "gender-citations-swe"
COLLECTION_NAME = "article-data"

plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['axes.titlesize'] = 16
plt.rcParams['axes.labelsize'] = 10


def get_df(collection, year):
    # Include 'PY' in the fields retrieved from MongoDB
    data = list(collection.find({}, {"AG": 1, "CP_gender": 1, "PY": 1, "_id": 0}))
    df = pd.DataFrame(data)
    # Filter rows where gender is not assigned to both authors
    clean_df = df.loc[~df['AG'].isin(['UM', 'MU', 'UU', 'WU', 'UW'])].reset_index(drop=True)
    # Further filter rows where before 2009
    clean_df = clean_df[clean_df['PY'].isin([year])]
    return clean_df


def conduct_analysis(df, WuW):
    year = df['PY'].unique()[0]
    AG_groups = df['AG'].value_counts().reset_index()
    # calculate the expected proportions
    AG_groups['expected_p'] = (AG_groups['count'] / AG_groups['count'].sum()) * 100

    flattened = df["CP_gender"].explode()

    cited_counts = {
        'MM': flattened.value_counts().get('MM', 0),
        'MW': flattened.value_counts().get('MW', 0),
        'WM': flattened.value_counts().get('WM', 0),
        'WW': flattened.value_counts().get('WW', 0)
    }
    # save the cited counts to df
    AG_groups['cited_count'] = AG_groups['AG'].map(cited_counts)

    # calculate the GCBI and add to df
    AG_groups['observed_p'] = (AG_groups['cited_count'] / AG_groups['cited_count'].sum()) * 100

    # combine the MW, WM, WW counts together
    if WuW:
        wuw_row = pd.DataFrame({
            'AG': ['WuW'],
            'count': [AG_groups[AG_groups['AG'].isin(['WM', 'MW', 'WW'])]['count'].sum()],
            'expected_p': [AG_groups[AG_groups['AG'].isin(['WM', 'MW', 'WW'])]['expected_p'].sum()],
            'cited_count': [AG_groups[AG_groups['AG'].isin(['WM', 'MW', 'WW'])]['cited_count'].sum()],
            'observed_p': [AG_groups[AG_groups['AG'].isin(['WM', 'MW', 'WW'])]['observed_p'].sum()]
        })

        # Filter out the 'WM', 'MW', 'WW' rows
        wuw_df = AG_groups[~AG_groups['AG'].isin(['WM', 'MW', 'WW'])]

        # Concatenate the DataFrame with the new 'WuW' row
        wuw_df = pd.concat([wuw_df, wuw_row], ignore_index=True)
        AG_groups = wuw_df

    AG_groups['index'] = ((AG_groups['observed_p'] - AG_groups['expected_p']) / AG_groups['expected_p'])
    AG_groups['PY'] = year

    return AG_groups


def plot_temporal(df, title, WuW):

    # Pivot the DataFrame to have 'PY' as the index and 'AG' as the columns
    pivot_df = df.pivot(index='PY', columns='AG', values='index')

    if WuW:
        custom_colors = ["#3320DC", "#b61a02"]
        legend_labels = ['Man and man', 'Woman and/or woman']
    else:
        custom_colors = ["#3320DC", "#8182EF", "#F58400", "#B64402"]
        legend_labels = ['Man and man', 'Man and woman', "Woman and man", "Woman and woman"]

    line_thickness = 1.5

    pivot_df.plot(kind='line', marker='.', figsize=(11, 7), color=custom_colors, linewidth=line_thickness)

    plt.ylabel('Gender Citation Balance Index')
    plt.xlabel("Year")
    plt.title(title)

    legend = plt.legend(title='Gender Category', labels=legend_labels)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(0.8)
    legend.get_frame().set_facecolor('white')

    # plt.ylim(-0.4, 0.2)  # Set the y-axis limits
    plt.grid(axis='y', linestyle=':', alpha=0.5, color='grey')
    plt.axhline(0, color='black', linewidth=1.0, linestyle='--')


def conduct_bootstrap_analysis(df, WuW, n=1000):

    def bootstrap(df, n):
        bootstrapped_samples = []
        for i in range(1, n + 1):
            sys.stdout.write(f"\rGenerating bootstrap sample: {i}")
            sys.stdout.flush()
            sample = df.sample(n=len(df), replace=True)
            bootstrapped_samples.append(sample)
        sys.stdout.write("\n")
        return bootstrapped_samples

    # create 1000 bootstrapped samples of the given dataset = df
    samples = bootstrap(df, n)
    i = 1

    if WuW:
        bootstrap_dict = {
            "MM": [],
            "WuW": [],
        }
        for dataset in samples:
            sys.stdout.write(f"\rAnalyzing bootstrap sample: {i}")
            sys.stdout.flush()

            analysis = conduct_analysis(dataset, WuW)

            index_of_MM = analysis.loc[analysis['AG'] == 'MM', 'index'].values[0]
            index_of_WuW = analysis.loc[analysis['AG'] == 'WuW', 'index'].values[0]

            bootstrap_dict['MM'].append(float(index_of_MM))
            bootstrap_dict['WuW'].append(float(index_of_WuW))
            i = i + 1

    else:
        bootstrap_dict = {
            "MM": [],
            "MW": [],
            "WM": [],
            "WW": []
        }

        for dataset in samples:
            sys.stdout.write(f"\rAnalyzing bootstrap sample: {i}")
            sys.stdout.flush()

            analysis = conduct_analysis(dataset, WuW)

            index_of_MM = analysis.loc[analysis['AG'] == 'MM', 'index'].values[0]
            index_of_MW = analysis.loc[analysis['AG'] == 'MW', 'index'].values[0]
            index_of_WM = analysis.loc[analysis['AG'] == 'WM', 'index'].values[0]
            index_of_WW = analysis.loc[analysis['AG'] == 'WW', 'index'].values[0]

            bootstrap_dict['MM'].append(float(index_of_MM))
            bootstrap_dict['MW'].append(float(index_of_MW))
            bootstrap_dict['WM'].append(float(index_of_WM))
            bootstrap_dict['WW'].append(float(index_of_WW))
            i = i + 1

    sys.stdout.write("\n")
    # stored indices from each bootstrapped sample
    bootstrap_result = pd.DataFrame(bootstrap_dict)

    def bootstrap_conf_interval(data, confidence=0.95):
        lower_percentile = (1 - confidence) / 2
        upper_percentile = 1 - lower_percentile
        lower_bound = np.percentile(data, lower_percentile * 100)
        upper_bound = np.percentile(data, upper_percentile * 100)
        return lower_bound, upper_bound

    # calculate intervals
    confidence_intervals = {}
    for column in bootstrap_result.columns:
        confidence_intervals[column] = bootstrap_conf_interval(bootstrap_result[column])

    confidence_intervals_df = pd.DataFrame.from_dict(confidence_intervals, orient='index',
                                                     columns=['lower', 'upper'])
    confidence_intervals_df['PY'] = year

    return confidence_intervals_df


def plot_with_ci(df, title, WuW):
    # Pivot the DataFrame for index, lower, and upper errors
    pivot_index = df.pivot(index='PY', columns='AG', values='index')
    pivot_error_lower = df.pivot(index='PY', columns='AG', values='error_lower')
    pivot_error_upper = df.pivot(index='PY', columns='AG', values='error_upper')

    if WuW:
        custom_colors = ["#3320DC", "#b61a02"]
        legend_labels = ['Man and man', 'Woman and/or woman']
    else:
        custom_colors = ["#3320DC", "#8182EF", "#F58400", "#B64402"]
        legend_labels = ['Man and man', 'Man and woman', "Woman and man", "Woman and woman"]

    line_thickness = 1.5

    # Plot the data with error bars
    plt.figure(figsize=(11, 7))

    # Loop through each AG group and plot it
    for idx, column in enumerate(pivot_index.columns):
        # Plot the line and points without transparency
        plt.plot(
            pivot_index.index,  # x values (Years)
            pivot_index[column],  # y values (Index)
            marker='.',  # marker style
            color=custom_colors[idx % len(custom_colors)],  # custom colors
            label=column,
            linewidth=line_thickness  # line thickness
        )

        # Plot the error bars with transparency
        plt.errorbar(
            pivot_index.index,  # x values (Years)
            pivot_index[column],  # y values (Index)
            yerr=[pivot_error_lower[column], pivot_error_upper[column]],  # error bars
            fmt='none',  # no line or marker
            ecolor=custom_colors[idx % len(custom_colors)],  # same color as the line
            capsize=5,  # length of the error bar caps
            elinewidth=line_thickness,  # line thickness for error bars
            alpha=0.3  # transparency for error bars
        )

    # Adding plot labels and title
    plt.ylabel('Gender Citation Balance Index')
    plt.xlabel("Year")
    plt.title(title)

    # Customizing the legend
    legend = plt.legend(title='Gender Category', labels=legend_labels)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(0.8)
    legend.get_frame().set_facecolor('white')

    # Additional plot styling
    plt.grid(axis='y', linestyle=':', alpha=0.5, color='grey')
    plt.axhline(0, color='black', linewidth=1.0, linestyle='--')


if __name__ == "__main__":
    # connect to mongoDB
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    collection = db[COLLECTION_NAME]

    # Full dataset with all cited groups ------------------------------------------------------------------------------
    print("PLOTTING WITH ALL CATEGORISES SEPARATED+++++++++++++++++++++++++++++++++++++++++++++++++++")
    result_list = []
    year_list = [2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024]
    for year in year_list:
        print(f"Processing: {year} ------------------------------")
        full_df = get_df(collection, year)
        result = conduct_analysis(full_df, False)
        ci = conduct_bootstrap_analysis(full_df, False, n=1000)

        index_mapping = result.set_index('AG')['index']
        ci['index'] = ci.index.map(index_mapping)
        result_ci = ci[['index', 'lower', 'upper', 'PY']]
        result_list.append(result_ci)

    # combine each year into one df
    result_df = pd.concat(result_list)
    result_df.reset_index(inplace=True)
    result_df.rename(columns={'level_0': 'AG'}, inplace=True)

    # Calculate the error margins
    result_df['error_lower'] = result_df['index'] - result_df['lower']
    result_df['error_upper'] = result_df['upper'] - result_df['index']

    plot_temporal(result_df, "Temporal Trend of Citation Patterns among Gender Categories", False)
    plt.savefig('temporal_figures/full_data.png', dpi=800)
    plot_with_ci(result_df, "Temporal Trend of Citation Patterns among Gender Categories", False)
    plt.savefig('temporal_figures/ci_full_data.png', dpi=800)

    # Full dataset with MM and WuW ------------------------------------------------------------------------------------
    print("PLOTTING WITH WOMAN GROUPED+++++++++++++++++++++++++++++++++++++++++++++++++++")
    result_list = []
    year_list = [2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024]
    for year in year_list:
        print(f"Processing: {year} ------------------------------")
        full_df = get_df(collection, year)
        result = conduct_analysis(full_df, True)
        ci = conduct_bootstrap_analysis(full_df, True, n=1000)

        index_mapping = result.set_index('AG')['index']
        ci['index'] = ci.index.map(index_mapping)
        result_ci = ci[['index', 'lower', 'upper', 'PY']]
        result_list.append(result_ci)

    # combine each year into one df
    result_df = pd.concat(result_list)
    result_df.reset_index(inplace=True)
    result_df.rename(columns={'level_0': 'AG'}, inplace=True)

    # Calculate the error margins
    result_df['error_lower'] = result_df['index'] - result_df['lower']
    result_df['error_upper'] = result_df['upper'] - result_df['index']

    plot_temporal(result_df, "Temporal Trend of Citation Patterns: Woman Authors Grouped", True)
    plt.savefig('temporal_figures/wuw_full_data.png', dpi=800)
    plot_with_ci(result_df, "Temporal Trend of Citation Patterns: Woman Authors Grouped", True)
    plt.savefig('temporal_figures/wuw_ci_full_data.png', dpi=800)
