import argparse
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.pyplot import figure
import warnings

warnings.filterwarnings("ignore", category=UserWarning)

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Generate query response time charts')
    parser.add_argument('--input', '-i', default='/tmp/bulk_result_query/query_input.csv',
                      help='Input CSV file path')
    parser.add_argument('--xlabel', '-x', default='queryType',
                      help='X-axis label name')
    parser.add_argument('--output', '-o', default='query_chart.png',
                      help='Output PNG file name')
    parser.add_argument('--queries', '-q', default=1000,
                      help='Number of queries')
    parser.add_argument('--mode', '-m', choices=['result', 'ratio'], default='result',
                      help='Mode: "result" to generate result chart, "ratio" to generate ratio chart')
    return parser.parse_args()

def load_data(file_path):
    """Load and preprocess data from CSV file."""
    # Define column names based on the expected CSV format
    col_names = ['database', 'use_case', 'query_type', 'scale', 'queries', 'workers', 'response_time', 'qps']
    
    # Read CSV file
    df = pd.read_csv(file_path, header=None, names=col_names)
    
    # Convert response time to numeric
    df['response_time'] = pd.to_numeric(df['response_time'], errors='coerce')
    
    # Drop rows with NaN values
    df = df.dropna(subset=['response_time'])
    
    return df

def get_color_map():
    """Return the color map for different database types."""
    return {
        'TDengine': '#1f77b4',       # Muted blue
        'TDengineStmt2': '#1f77b4',  # Muted blue
        'influx': '#ff7f0e',         # Muted orange
        'influx3': '#2ca02c',        # Muted green
        'timescaledb': '#bcbd22'     # Muted yellow-green
    }

def calculate_ratios(df, baseline_db='TDengine'):
    """Calculate response time ratios relative to the baseline database."""
    # Check if baseline_db exists in the data
    if baseline_db not in df['database'].unique():
        print(f"Error: Baseline database {baseline_db} not found in the data.")
        return pd.DataFrame()  # Return an empty DataFrame
    
    # Get unique query types
    query_types = df['query_type'].unique()
    
    result_data = []
    
    # Process each query type separately
    for query_type in query_types:
        query_df = df[df['query_type'] == query_type]
        
        # Get baseline response time for this query type
        baseline = query_df[query_df['database'] == baseline_db]['response_time'].values
        
        if len(baseline) == 0:
            print(f"Warning: No {baseline_db} data found for query type {query_type}")
            continue
            
        baseline_time = baseline[0]
        
        # Calculate ratio for each database
        for db_name, db_group in query_df.groupby('database'):
            if db_name == baseline_db:
                ratio = 100.0  # Baseline is 100%
            else:
                # Higher ratio means other DB takes more time than baseline
                ratio = (db_group['response_time'].values[0] / baseline_time) * 100
                
            result_data.append({
                'database': db_name,
                'query_type': query_type,
                'response_time': db_group['response_time'].values[0],
                'ratio': ratio,
                'scale': db_group['scale'].values[0],
                'workers': db_group['workers'].values[0]
            })
    
    # Convert to DataFrame
    result_df = pd.DataFrame(result_data)
    return result_df

def create_result_chart(df, x_label_name, query_times, output_file):
    """Create horizontal bar chart showing response times."""
    # Set figure size and initialize plot
    fig = figure(figsize=(16, 12), dpi=300, layout='constrained')
    ax = plt.subplot(1, 1, 1)
    
    # Get unique values for grouping
    query_types = df['query_type'].unique()
    databases = df['database'].unique()
    
    # Define bar properties
    bar_positions = np.arange(0, len(query_types) * 6, 6)
    bar_width = 1.5
    
    # Get color map
    color_map = get_color_map()
    
    # Track which database is shown at which position
    db_positions = {}
    for i, db in enumerate(databases):
        if db == 'TDengine':  # Ensure TDengine is at position 0
            db_positions[db] = 0
        else:
            db_positions[db] = (i if db != 'TDengine' else 0) * bar_width
    
    # Plot each database
    for i, db_name in enumerate(databases):
        db_data = df[df['database'] == db_name]
        
        # Skip if no data for this database
        if len(db_data) == 0:
            continue
            
        # Prepare data for plotting
        response_times = []
        positions = []
        query_labels = []
        
        for j, query_type in enumerate(query_types):
            query_data = db_data[db_data['query_type'] == query_type]
            if len(query_data) > 0:
                response_times.append(query_data['response_time'].values[0])
                positions.append(bar_positions[j] + db_positions[db_name])
                query_labels.append(query_type)
        
        # Plot bars with specified colors
        ax.barh(positions, response_times, height=bar_width, label=f"{db_name}", color=color_map.get(db_name, 'gray'))
        
        # Add text labels to bars
        for pos, response_time in zip(positions, response_times):
            plt.text(response_time + 2, pos, f'{response_time:.1f}', ha='left', va='center', fontsize=8)
    
    # Get scale label from data
    scale_label = df['scale'].iloc[0] if len(df) > 0 else "unknown"
    
    # Configure chart appearance
    ax.invert_yaxis()
    ax.set_yticks(bar_positions)
    ax.set_yticklabels(query_types)
    ax.set_xscale('log')  # Set x-axis to log scale
    ax.set_xlabel("Response time (ms)")
    ax.set_title(
        f"Query Comparison: Response time in different {x_label_name} on {scale_label} device * 10 metrics, "
        f"number of queries: {query_times}", 
        loc='left', 
        fontsize=10
    )
    ax.legend(loc='upper right')
    
    # Save figure
    plt.grid(axis='x', linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(output_file)
    print(f"Chart saved to {output_file}")
    plt.close()

def create_ratio_chart(df, x_label_name, query_times, output_file):
    """Create horizontal bar chart showing response time ratios."""
    # Set figure size and initialize plot
    fig = figure(figsize=(16, 12), dpi=300, layout='constrained')
    ax = plt.subplot(1, 1, 1)
    
    # Get unique values for grouping
    query_types = df['query_type'].unique()
    databases = df['database'].unique()
    
    # Define bar properties
    bar_positions = np.arange(0, len(query_types) * 6, 6)
    bar_width = 1.5
    
    # Get color map
    color_map = get_color_map()
    
    # Track which database is shown at which position
    db_positions = {}
    for i, db in enumerate(databases):
        if db == 'TDengine':  # Ensure TDengine is at position 0
            db_positions[db] = 0
        else:
            db_positions[db] = (i if db != 'TDengine' else 0) * bar_width
    
    # Plot each database
    for i, db_name in enumerate(databases):
        db_data = df[df['database'] == db_name]
        
        # Skip if no data for this database
        if len(db_data) == 0:
            continue
            
        # Prepare data for plotting
        ratios = []
        positions = []
        query_labels = []
        
        for j, query_type in enumerate(query_types):
            query_data = db_data[db_data['query_type'] == query_type]
            if len(query_data) > 0:
                ratios.append(query_data['ratio'].values[0])
                positions.append(bar_positions[j] + db_positions[db_name])
                query_labels.append(query_type)
        
        # Plot bars with specified colors
        ax.barh(positions, ratios, height=bar_width, label=f"{db_name}", color=color_map.get(db_name, 'gray'))
        
        # Add text labels to bars
        for pos, ratio in zip(positions, ratios):
            plt.text(ratio + 2, pos, f'{ratio:.1f}%', ha='left', va='center', fontsize=8)
    
    # Get scale label from data
    scale_label = df['scale'].iloc[0] if len(df) > 0 else "unknown"
    
    # Configure chart appearance
    ax.invert_yaxis()
    ax.set_yticks(bar_positions)
    ax.set_yticklabels(query_types)
    ax.axvline(100, color='gray', linewidth=1, linestyle='--')
    ax.set_xscale('log')  # Set x-axis to log scale
    ax.set_xlabel("Response time ratio (% relative to TDengine)")
    ax.set_title(
        f"Query Comparison: Response time ratio in different {x_label_name} on {scale_label} device * 10 metrics, "
        f"number of queries: {query_times}", 
        loc='left', 
        fontsize=10
    )
    ax.legend(loc='upper right')
    
    # Save figure
    plt.grid(axis='x', linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(output_file)
    print(f"Chart saved to {output_file}")
    plt.close()

def main():
    # Parse arguments
    args = parse_args()
    
    print(f"Loading data from {args.input}")
    
    # Load and process data
    df = load_data(args.input)
    
    if df.empty:
        print("Error: No valid data found in the input file")
        sys.exit(1)
    
    if args.mode == 'ratio':
        # Calculate ratios
        result_df = calculate_ratios(df)
        
        if result_df.empty:
            print("Error: Could not calculate ratios. Check if TDengine data exists.")
            sys.exit(1)
        
        # Create ratio chart
        output_file = args.output.replace('.png', '_ratio.png')
        create_ratio_chart(result_df, args.xlabel, args.queries, output_file)
    else:
        # Create result chart
        output_file = args.output.replace('.png', '_result.png')
        create_result_chart(df, args.xlabel, args.queries, output_file)
    
    print("Processing complete.")

if __name__ == "__main__":
    # 忽略 UserWarning
    warnings.filterwarnings("ignore", category=UserWarning, message=".*tight_layout.*")
    main()