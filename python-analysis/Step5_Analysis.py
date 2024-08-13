from pymongo import MongoClient
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys
'''
Computes the Gender Citation Balance Index, bootstraps and plots the results.
This section does the mentioned on the full dataset, as well as the gender subsets

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
    # Include 'PY' in the fields retrieved from MongoDB
    data = list(collection.find({}, {"AG": 1, "CP_gender": 1, "PY": 1, "_id": 0}))
    df = pd.DataFrame(data)
    # Filter rows where gender is not assigned to both authors
    clean_df = df.loc[~df['AG'].isin(['UM', 'MU', 'UU', 'WU', 'UW'])].reset_index(drop=True)
    # Further filter rows where before 2009
    clean_df = clean_df[clean_df['PY'].isin([2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024])]

    return clean_df


def get_subset(full_df, cat):
    return full_df[full_df['AG'] == cat].reset_index(drop=True)


def conduct_analysis(df):
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
    AG_groups['index'] = ((AG_groups['observed_p'] - AG_groups['expected_p']) / AG_groups['expected_p'])

    return AG_groups


def conduct_analysis_by_group(expected_p_df, group_df):

    # isolate based on gender group authored papers
    flattened = group_df["CP_gender"].explode()
    cited_counts = {
        'MM': flattened.value_counts().get('MM', 0),
        'MW': flattened.value_counts().get('MW', 0),
        'WM': flattened.value_counts().get('WM', 0),
        'WW': flattened.value_counts().get('WW', 0)
    }

    group_df = pd.DataFrame(list(cited_counts.items()), columns=['CP_gender', 'cited_count'])
    group_df['observed_p'] = (group_df['cited_count'] / group_df['cited_count'].sum()) * 100

    # Merge the DataFrames on AG and CP_gender
    result_df = group_df.merge(expected_p_df, left_on='CP_gender', right_on='AG')
    result_df = result_df.drop(columns='CP_gender')  # Drop the redundant AG column from the merged DataFrame
    # calculate the GCBI and add to df
    result_df['index'] = ((result_df['observed_p'] - result_df['expected_p']) / result_df['expected_p'])
    result_df = result_df[['AG', 'expected_p', 'cited_count', 'observed_p', 'index']]

    return result_df


def bootstrap(df, n=1000):
    bootstrapped_samples = []
    for i in range(1, n + 1):
        sys.stdout.write(f"\rGenerating bootstrap sample: {i}")
        sys.stdout.flush()
        sample = df.sample(n=len(df), replace=True)
        bootstrapped_samples.append(sample)
    sys.stdout.write("\n")
    return bootstrapped_samples


def bootstrap_conf_interval(data, confidence=0.95):
    lower_percentile = (1 - confidence) / 2
    upper_percentile = 1 - lower_percentile
    lower_bound = np.percentile(data, lower_percentile * 100)
    upper_bound = np.percentile(data, upper_percentile * 100)
    return lower_bound, upper_bound


def conduct_bootstrap_analysis(df, expected_proportion, cat, n=1000):
    # create 1000 bootstrapped samples of the given dataset = df
    samples = bootstrap(df, n)

    bootstrap_dict = {
        "MM": [],
        "MW": [],
        "WM": [],
        "WW": []
    }
    i = 1
    for dataset in samples:
        sys.stdout.write(f"\rAnalyzing bootstrap sample: {i}")
        sys.stdout.flush()
        if cat == "ALL":
            analysis = conduct_analysis(dataset)
        else:
            analysis = conduct_analysis_by_group(expected_proportion, dataset)

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

    # calculate intervals
    confidence_intervals = {}
    for column in bootstrap_result.columns:
        confidence_intervals[column] = bootstrap_conf_interval(bootstrap_result[column])

    # Display the confidence intervals
    for column, interval in confidence_intervals.items():
        print(f"{column}: {interval}")

    return confidence_intervals


def plot(result, conf_intervals, subset=None):
    # Reorder the DataFrame according to the specified order
    order = ['MM', 'MW', 'WM', 'WW']
    df_ordered = result.set_index('AG').loc[order].reset_index()
    rename_map = {
        'MM': 'Man & man',
        'MW': 'Man & woman',
        'WM': 'Woman & man',
        'WW': 'Woman & Woman'
    }
    df_ordered['AG'] = df_ordered['AG'].replace(rename_map)

    custom_colors = ["#3320DC", "#8182EF", "#F58400", "#B64402"]

    # Extract the means and confidence intervals
    means = df_ordered['index']
    lower_bounds = [conf_intervals[ag][0] for ag in order]
    upper_bounds = [conf_intervals[ag][1] for ag in order]
    errors = [(mean - lower, upper - mean) for mean, lower, upper in zip(means, lower_bounds, upper_bounds)]
    errors = np.array(errors).T

    # Plot the index (GCBI) column as a bar plot in the specified order
    plt.figure(figsize=(12, 8))
    bars = plt.bar(df_ordered['AG'], df_ordered['index'], edgecolor='black', color=custom_colors, yerr=errors, capsize=15, alpha=0.8)
    plt.ylabel('Gender Citation Balance Index')
    if subset is None:
        plt.title('Citation Patterns of Gender Categories')
    else:
        plt.title(f'Citing Patterns of {subset} Authors')

    plt.grid(axis='y', linestyle=':', alpha=0.5, color='grey')
    plt.axhline(0, color='black', linewidth=1.5, linestyle='--')
    plt.ylim(-0.4, 0.62)  # Set the y-axis limits

    # Annotate bars with their values and error intervals
    y_offset = 0.01  # Adjust this value to move the text further away vertically
    x_offset = 0.0  # Adjust this value to move the text further away horizontally
    for bar, lower, upper in zip(bars, lower_bounds, upper_bounds):
        height = bar.get_height()
        error = (upper - lower) / 2
        plt.text(
            bar.get_x() + bar.get_width() / 2.0 + x_offset,  # X-coordinate: center of the bar plus offset
            upper + y_offset if height >= 0 else lower - y_offset,
            # Y-coordinate: upper bound of the error bar plus/minus offset
            f'{height:.3f} ± {error:.3f}',  # Text: bar height and error formatted to 3 decimal places
            ha='center',  # Horizontal alignment
            va='bottom' if height >= 0 else 'top'  # Vertical alignment
        )


if __name__ == "__main__":
    # connect to mongoDB
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    collection = db[COLLECTION_NAME]

    # get full data set
    full_df = get_df(collection)

    # get the expected proportion
    # required for category calculation at will be used as the base rate
    expected_p = conduct_analysis(full_df)[['AG', 'expected_p']]
    n = 1000   # bootstrapped iterations

    # Full dataset analysis----------------------------------------------------------------------------
    print("\nALL Data Analysis-------------------------------------------------------------------------")
    full_result = conduct_analysis(full_df)
    print(full_result)
    print(f"Total Citations: {full_result['cited_count'].sum()}")
    print(f" Total Articles: {len(full_df)}")

    # bootstrap
    full_ci = conduct_bootstrap_analysis(full_df, expected_p, "ALL", n)
    plot(full_result, full_ci)
    plt.savefig('figures/full_data_indices.png', dpi=800)

    # Subset analyses----------------------------------------------------------------------------
    print("\nMM Data Analysis-------------------------------------------------------------------------")
    MM_df = get_subset(full_df, "MM")
    MM_result = conduct_analysis_by_group(expected_p, MM_df)
    print(MM_result)
    print(f"Total Citations: {MM_result['cited_count'].sum()}")
    print(f" Total Articles: {len(MM_df)}")

    # bootstrap
    MM_ci = conduct_bootstrap_analysis(MM_df, expected_p, "MM", n)
    plot(MM_result, MM_ci, "Man & Man")
    plt.savefig('figures/MM_data_indices.png', dpi=800)

    print("\nMW Data Analysis-------------------------------------------------------------------------")
    MW_df = get_subset(full_df, "MW")
    MW_result = conduct_analysis_by_group(expected_p, MW_df)
    print(MW_result)
    print(f"Total Citations: {MW_result['cited_count'].sum()}")
    print(f" Total Articles: {len(MW_df)}")

    # bootstrap
    MW_ci = conduct_bootstrap_analysis(MW_df, expected_p, "MW", n)
    plot(MW_result, MW_ci, "Man & Woman")
    plt.savefig('figures/MW_data_indices.png', dpi=800)

    print("\nWM Data Analysis-------------------------------------------------------------------------")
    WM_df = get_subset(full_df, "WM")
    WM_result = conduct_analysis_by_group(expected_p, WM_df)
    print(WM_result)
    print(f"Total Citations: {WM_result['cited_count'].sum()}")
    print(f" Total Articles: {len(WM_df)}")

    # bootstrap
    WM_ci = conduct_bootstrap_analysis(WM_df, expected_p, "WM", n)
    plot(WM_result, WM_ci, "Woman & Man")
    plt.savefig('figures/WM_data_indices.png', dpi=800)

    print("\nWW Data Analysis-------------------------------------------------------------------------")
    WW_df = get_subset(full_df, "WW")
    WW_result = conduct_analysis_by_group(expected_p, WW_df)
    print(WW_result)
    print(f"Total Citations: {WW_result['cited_count'].sum()}")
    print(f" Total Articles: {len(WW_df)}")

    # bootstrap
    WW_ci = conduct_bootstrap_analysis(WW_df, expected_p, "WW", n)
    plot(WW_result, WW_ci, "Woman & Woman")
    plt.savefig('figures/WW_data_indices.png', dpi=800)

    print("\nWuW Data Analysis-------------------------------------------------------------------------")
    WuW_df = pd.concat([MW_df, WM_df, WW_df], axis=0, ignore_index=True)
    WuW_result = conduct_analysis_by_group(expected_p, WuW_df)
    print(WuW_result)
    print(f"Total Citations: {WuW_result['cited_count'].sum()}")
    print(f" Total Articles: {len(WuW_df)}")

    # bootstrap
    WuW_ci = conduct_bootstrap_analysis(WuW_df, expected_p, "WuW", n)
    plot(WuW_result, WuW_ci, "Woman and/or Woman")
    plt.savefig('figures/WuW_data_indices.png', dpi=800)

